
#include <stdio.h>
#include <stdlib.h>
#include <cassert>

#include <ruby.h>
#include "ruby/ruby.h"
#include "ruby/thread.h"
#include <vector>
#include <iostream>
#include <unordered_map>
#include <set>
#include <algorithm>
#include <sstream>

#ifdef _OPENMP
#include <omp.h>
#endif

#include "unordered_dense.h"

using std::cout;
using std::pair;
using std::string;
using std::vector;

std::vector<std::string> splitString(const std::string &input, const char &separator) {
  std::vector<std::string> result;
  std::stringstream ss(input);
  std::string item;

  // while (std::getline(ss, item, '/') || std::getline(ss, item, '\\')) {
  while (std::getline(ss, item, separator)) {
    if (item.size() > 0) {
      result.push_back(item);
    }
  }

  return result;
}

// Function to convert int64_t to binary string,
std::string int64ToBinaryString(int64_t num) {
  std::string result;
  for (int i = 63; i >= 0; --i) {
    result += ((num >> i) & 1) ? '1' : '0';
  }
  return result;
}

std::string int64ToStr(int64_t key) {

  int nchars = 8;
  std::string str;
  int multip = nchars * 8;
  for (int i = 0; i <= nchars; i++) {
    char c = (key >> multip) & 255;
    str.push_back(c);
    multip -= 8;
  }
  return str;
}

void printVector(const std::vector<int> &vec) {
  for (const auto &value : vec) {
    std::cout << value << " ";
  }
}

std::string charToBinaryString(char num) {
  std::string result;
  for (int i = 7; i >= 0; --i) {
    result += ((num >> i) & 1) ? '1' : '0';
  }
  return result;
}

class Candidate;
enum segmentType { Dir, File };
// A segment of a file path
// e.g. if path is /foo/bar/baz.txt
// segments are [{root}, foo, bar, baz.txt]
class PathSegment {
public:
  std::string str;
  int fileId; // (if FILE)
  Candidate *cand;
  PathSegment *parent;
  ankerl::unordered_dense::map<std::string, PathSegment *> children;
  segmentType type = Dir;
  PathSegment() : parent(NULL) {}
  PathSegment(std::string _str) : str(_str), parent(NULL) {}
  PathSegment(std::string _str, int _fileId)
      : str(_str), fileId(_fileId), cand(NULL), parent(NULL) {}
};

// Candidate for result in string (filename) search
class Candidate {
public:
  std::vector<int> v_charscore;
  PathSegment *seg;
  int fileId;
  // The string that this candidate represents
  string str;
  int len; // Query string length

  float minscore;
  float maxscore;
  int candLen; // Length of candidate

  Candidate() { v_charscore.resize(20, 8888); };
  Candidate(int _fileId, string _str, int _len) : fileId(_fileId), str(_str), len(_len) {
    // Initialize v_charscores with zeros
    v_charscore.resize(len, 0);
    candLen = str.size();
    seg = NULL;
  }

  Candidate(PathSegment *_seg, int _len) : seg(_seg), len(_len) {
    // Initialize v_charscores with zeros
    v_charscore.resize(len, 0);
    candLen = seg->str.size();
  }

  float getScore() {
    int i = 0;
    float score = 0.0;
    for (int &charscore : v_charscore) {
      score += charscore;
      i++;
    }
    float div = len * len;
    float div2 = len * candLen;
    float score1 = score / div;
    float score2 = score / div2;
    score = score1 * 0.97 + score2 * 0.03;
    return score;
  }

  int operator[](int idx) { return v_charscore[idx]; }
  // TODO: all
};

// This seems to give 10x speed improvement over std::unordered_map
typedef ankerl::unordered_dense::map<int64_t, std::set<PathSegment *> *> SegMap;
// typedef std::unordered_map<int64_t, std::set<PathSegment *> *> SegMap;

typedef std::unordered_map<float, Candidate> CandMap;

class StringIndex {
public:
  int tmp;

  std::vector<SegMap *> dirmaps;
  std::vector<SegMap *> filemaps;

  std::vector<PathSegment *> segsToClean;

  std::unordered_map<int, std::string> strlist;
  std::unordered_map<int, PathSegment *> seglist;
  PathSegment *root;
  int dirId = 0;

  StringIndex() {
    root = new PathSegment();
    root->parent = NULL;
    root->str = "[ROOT]";

    for (int i = 0; i <= 8; i++) {
      dirmaps.push_back(new SegMap);
      filemaps.push_back(new SegMap);
    }

#ifdef _OPENMP
    std::cout << "OPENMP enabled\n";
#endif
  }

  ~StringIndex() {
    for (auto x : dirmaps) {
      for (auto y : *x) {
        y.second->clear();
        delete (y.second);
      }
      x->clear();
      delete x;
    }
    for (auto x : filemaps) {
      for (auto y : *x) {
        y.second->clear();
        delete (y.second);
      }
      x->clear();
      delete x;
    }
    clearPathSegmentChildren(root);
  }
  void clearPathSegmentChildren(PathSegment *p) {
    if (p->children.size() > 0) {
      for (auto x : p->children) {
        clearPathSegmentChildren(x.second);
      }
    }
    delete p;
  }

  void addPathSegmentKeys(PathSegment *p) {
    // Input p is part of a path, e.g. 'barxyz' if path is /foo/barxyz/baz.txt
    // This function generates int64 representations (keys) of all substrings of size 2..8 in that
    // path segment and stores pointer to p in hash tables using these int values as keys.

    int nchars = 8;
    std::string str = p->str;
    if (p->str.size() < 2) {
      return;
    }
    if (p->str.size() < nchars) {
      nchars = p->str.size();
    }

    for (; nchars >= 2; nchars--) {
      SegMap *map;
      if (p->type == File) {
        map = filemaps[nchars];
      } else {
        map = dirmaps[nchars];
      }

      for (int i = 0; i <= str.size() - nchars; i++) {
        int64_t key = getKeyAtIdx(str, i, nchars);

        // Create a new std::set for key if doesn't exist already
        auto it = map->find(key);
        if (it == map->end()) {
          (*map)[key] = new std::set<PathSegment *>;
        }
        (*map)[key]->insert(p);
      }
    }
  }

  void addSegments(std::string str, int fileId, const char &separator) {
    auto segs = splitString(str, separator);
    PathSegment *prev = NULL;
    // auto it = root.children.find(segs[0]);
    // if (it != root.children.end()) {
    // cout << "found in root";
    // }
    prev = root;
    // for (auto x : segs) {
    for (auto _x = segs.begin(); _x != segs.end(); ++_x) {
      auto x = *_x;
      // cout << "(" << x << ")";
      PathSegment *p;

      auto it = prev->children.find(x);
      if (it != prev->children.end()) {
        // cout << "<f>"; // Found
        p = it->second;
      } else {
        p = new PathSegment(x, fileId);
        p->parent = prev;
        // If this is last item in segs
        if (_x == std::prev(segs.end())) {
          // cout << "[L]";
          p->type = File;
          seglist[fileId] = p;
        } else {
          p->type = Dir;
          p->fileId = dirId;
          dirId++;
        }
        prev->children[x] = p;
        addPathSegmentKeys(p);
      }

      // if (prev != NULL) {
      // }

      prev = p;
    }
    // cout << " \n";
  }

  // template <typename T>
  std::vector<PathSegment *> findSimilarForNgram2(std::string str, int i, int nchars, SegMap &map) {

    assert(i + nchars <= str.size());
    std::vector<PathSegment *> res;

    int64_t key = getKeyAtIdx(str, i, nchars);
    // std::cout << "findSimilar " << str << " " << nchars << "\n";
    auto it = map.find(key);
    if (it != map.end()) { // key found
      auto set = it->second;
      for (auto value : *set) {
        res.push_back(value);
        // std::cout << value << " \n";
      }
    }
    return res;
  }

  void addToCandMap(CandMap &candmap, std::string query,
                    std::vector<SegMap *> &map // filemaps or dirmaps
  ) {
    int nchars = 8;
    int minChars = 2; // TODO
    if (query.size() < nchars) {
      nchars = query.size();
    }

    for (; nchars >= minChars; nchars--) {
      int count = query.size() - nchars + 1;
      for (int i = 0; i < count; i++) {
        auto res = findSimilarForNgram2(query, i, nchars, *(map[nchars]));
        for (PathSegment *p : res) {
          // cout << nchars << "|" << p->str << "\n";
          addToResults2(p, query, i, nchars, candmap);
        }
      }
    }
  }

  // Add parent directories scores to files
  void mergeCandidateMaps(CandMap &fileCandMap, CandMap &dirCandMap) {

    // TODO: make configurable
    float multip = 0.7; // Give only 70% of score if match is for directory
    for (auto &[fid, cand] : fileCandMap) {
      PathSegment *p = cand.seg->parent;
      while (p->parent != NULL) {
        if (p->cand != NULL) {
          auto &scoreA = cand.v_charscore;
          auto &scoreB = p->cand->v_charscore;
          for (int i = 0; i < cand.len; i++) {
            if (scoreA[i] < scoreB[i] * multip) {
              scoreA[i] = scoreB[i] * multip;
            }
          }
        }
        p = p->parent;
      }
    }
  }

  vector<pair<float, int>> findSimilar2(std::string query, int minChars) {
    CandMap fileCandMap;
    CandMap dirCandMap;

    addToCandMap(fileCandMap, query, filemaps);
    addToCandMap(dirCandMap, query, dirmaps);

    mergeCandidateMaps(fileCandMap, dirCandMap);

    // Set all candidate pointers to NULL so they won't mess up future searches
    for (auto seg : segsToClean) {
      seg->cand = NULL;
    }
    segsToClean.clear();

    // Form return result, 2d array with file id's and scores
    vector<pair<float, int>> results;
    for (auto &[fid, cand] : fileCandMap) {
      pair<float, int> v;
      float sc = cand.getScore();
      v.first = sc;
      v.second = fid;
      results.push_back(v);
    }
    // Sort highest score first
    std::sort(results.begin(), results.end(),
              [](pair<float, int> a, pair<float, int> b) { return a.first > b.first; });
    return results;
  }

  // Return int64_t representation of the first nchars in str, starting from index i
  int64_t getKeyAtIdx(std::string str, int i, int nchars) {
    int64_t key = 0;
    for (int i_char = 0; i_char < nchars; i_char++) {
      key = key | static_cast<int>(str[i + i_char]);
      if (i_char < nchars - 1) {
        // Shift 8 bits to the left except on the last iteration
        key = key << 8;
      }
    }
    return key;
  }

  void addToResults2(PathSegment *seg, std::string str, int i, int nchars, CandMap &candmap) {

    auto it2 = candmap.find(seg->fileId);
    if (it2 == candmap.end()) {
      // cout << "candmap " << seg->fileId << "\n";
      Candidate cand(seg, str.size());
      seg->cand = &(candmap[seg->fileId]);
      segsToClean.push_back(seg);
      candmap[seg->fileId] = cand;
    }

    for (int j = i; j < i + nchars; j++) {
      if (candmap[seg->fileId][j] < nchars) {
        candmap[seg->fileId].v_charscore[j] = nchars;
      }
    }
  }
};

// StringIndex *idxo;

extern "C" {

void str_idx_free(void *data) {
  delete (StringIndex *)data;
}


// Wrap StringIndex inside ruby variable
static const rb_data_type_t str_idx_type = {
		// .wrap_struct_name: "doesn’t really matter what it is as long as it’s sensible and unique"
    .wrap_struct_name = "StringIndexW9q4We",
    
    // Used by Carbage Collector:
    .function =
        {
            .dmark = NULL,
            .dfree = str_idx_free,
            .dsize = NULL, // TODO
        },
    .data = NULL,
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
};

VALUE str_idx_alloc(VALUE self) {
  void *data = new StringIndex();
  return TypedData_Wrap_Struct(self, &str_idx_type, data);
}

VALUE StringIndexAddSegments(VALUE self, VALUE str, VALUE fileId) {
  std::string s1 = StringValueCStr(str);
  int fid = NUM2INT(fileId);

  void *data;
  TypedData_Get_Struct(self, int, &str_idx_type, data);
  ((StringIndex *)data)->addSegments(s1, fid, '/');

  return self;
}

VALUE StringIndexFind(VALUE self, VALUE str, VALUE minChars) {
  VALUE ret;
  std::string s1 = StringValueCStr(str);

  void *data;
  TypedData_Get_Struct(self, int, &str_idx_type, data);
  StringIndex *idx = (StringIndex *)data;

  ret = rb_ary_new();
  const vector<pair<float, int>> &results = idx->findSimilar2(s1, NUM2INT(minChars));
  int limit = 15;
  int i = 0;
  for (const auto &res : results) {
    VALUE arr = rb_ary_new();
    rb_ary_push(arr, INT2NUM(res.second));
    rb_ary_push(arr, DBL2NUM(res.first));
    rb_ary_push(ret, arr);
    i++;
    if (i >= limit) {
      break;
    }
  }
  return ret;
}

void Init_stridx(void) {

  VALUE cFoo = rb_define_class("CppStringIndex", rb_cObject);

  rb_define_alloc_func(cFoo, str_idx_alloc);
  rb_define_method(cFoo, "add", StringIndexAddSegments, 2);
  rb_define_method(cFoo, "find", StringIndexFind, 2);
}

} // End extern "C"
