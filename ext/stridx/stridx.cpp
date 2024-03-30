
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
  // - type: {FILE, DIR}
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
  // - vector<PathSegment*> children
  // PathMap children; //or Set
  // - addChild(PathSegment*);
  // - FileCandidate* cand; // Null if not a candidate. Clear these at the end. used to find if
  // parent dirs of file are a candidate
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
    // cout << "zz len:" << len << " " << str.size() << "\n";
    candLen = str.size();
    seg = NULL;
  }

  Candidate(PathSegment *_seg, int _len) : seg(_seg), len(_len) {
    // Initialize v_charscores with zeros
    v_charscore.resize(len, 0);
    candLen = seg->str.size();
    // cout << "len:" << len << " " << candLen << " " << seg->str << "\n";
  }

  // Candidate(PathSegment *_seg, string _str, int _len) : seg(_seg), str(_str), len(_len) {
  // Initialize v_charscores with zeros
  // v_charscore.resize(len, 0);
  // }

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
typedef ankerl::unordered_dense::map<int64_t, std::set<int> *> HashMap;
// typedef std::unordered_map<int64_t, std::set<int> *> HashMap;

typedef ankerl::unordered_dense::map<std::string, std::set<PathSegment> *> StringMap;
typedef ankerl::unordered_dense::map<int64_t, std::set<PathSegment *> *> SegMap;

typedef std::unordered_map<int, Candidate> CandMap;

class StringIndex {
public:
  int tmp;

  std::vector<HashMap *> ngmaps;

  std::vector<SegMap *> dirmaps;
  std::vector<SegMap *> filemaps;

  std::vector<PathSegment *> segsToClean;

  std::unordered_map<int, std::string> strlist;
  std::unordered_map<int, PathSegment *> seglist;
  // int minChars = 3;
  PathSegment root;
  int dirId = 0;

  StringIndex() {
    root.parent = NULL;
    root.str = "[ROOT]";

    // PathSegment root("/");

    for (int i = 0; i <= 8; i++) {
      ngmaps.push_back(new HashMap);
      dirmaps.push_back(new SegMap);
      filemaps.push_back(new SegMap);
    }

#ifdef _OPENMP
    std::cout << "OPENMP enabled\n";
#endif

    // for (auto const& [key, val] : map) {
    // std::cout << key << " => " << val << std::endl;
    // }

    // children
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
    prev = &root;
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

  void mergeCandMaps(CandMap &fileCandMap, CandMap &dirCandMap) {

    // vector<pair<float, int>> results;
    // cout << "cand map size: " << candmap.size() << "\n";
    for (auto &[fid, cand] : fileCandMap) {
      PathSegment *p = cand.seg->parent;
      // cout << cand.seg->str << "|";
      while (p->parent != NULL) {
        // cout << p->str << "!";
        if (p->cand != NULL) {
          auto &scoreA = cand.v_charscore;
          auto &scoreB = p->cand->v_charscore;
          // cout << "[:]" << scoreB.size() << "|";

          for (int i = 0; i < cand.len; i++) {
            // cout << "[" << i << ":" << scoreA[i] << ":" << scoreB[i] << "]";
            // Todo: segfault for scoreB
            if (scoreA[i] < scoreB[i]) {

              scoreA[i] = scoreB[i];
            }
          }
        }
        p = p->parent;
      }
      // cout << "\n";
    }
  }

  vector<pair<float, int>> findSimilar2(std::string query, int minChars) {
    // minChars

    cout << "query " << query << "\n";
    CandMap fileCandMap;
    CandMap dirCandMap;
    CandMap &candmap = fileCandMap;
    // std::unordered_map<int, Candidate> &candmap = fileCandMap;

    addToCandMap(fileCandMap, query, filemaps);
    // cout << "======DIRS=================\n";
    addToCandMap(dirCandMap, query, dirmaps);

    mergeCandMaps(fileCandMap, dirCandMap);

    for (auto seg : segsToClean) {
      seg->cand = NULL;
    }
    segsToClean.resize(0);

    // 2d array with file id's and scores
    vector<pair<float, int>> results;
    // cout << "cand map size: " << candmap.size() << "\n";
    for (auto &[fid, cand] : candmap) {
      pair<float, int> v;
      float sc = cand.getScore();
      v.first = sc;
      v.second = fid;
      results.push_back(v);
      // cout << "score2: " << v.first;
    }
    // std::sort(results.begin(), results.end());
    // Sort largest score first
    std::sort(results.begin(), results.end(),
              [](pair<float, int> a, pair<float, int> b) { return a.first > b.first; });
    return results;
  }

  void dumpStatus() {

    int nchars = 6;
    for (const auto &[key, value] : (*ngmaps[nchars])) {
      int64_t x;
      x = key;
      int multip = nchars * 8;
      for (int i = 0; i <= nchars; i++) {
        char c = (x >> multip) & 255;
        std::cout << c;
        multip -= 8;
      }
      std::cout << "\n";
      for (auto y : *value) {
        std::cout << y << " ";
      }
      std::cout << "\n";
    }
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

  void addToIdx(std::string s1, int fileId, int nchars) {

    HashMap *ngmap = ngmaps[nchars];

    for (int i = 0; i <= s1.size() - nchars; i++) {
      // std::cout << "key: " << int64ToBinaryString(key) << "\n";
      int64_t key = getKeyAtIdx(s1, i, nchars);

      // Create a new std::set for key if doesn't exist already
      auto it = (*ngmap).find(key);
      if (it == (*ngmap).end()) {
        (*ngmap)[key] = new std::set<int>;
      }
      (*ngmap)[key]->insert(fileId);
    }
  }

  std::vector<int> findSimilarForNgram(std::string str, int i, int nchars) {

    assert(i + nchars <= str.size());
    std::vector<int> res;

    auto ngmap = *(ngmaps[nchars]);
    int64_t key = getKeyAtIdx(str, i, nchars);
    // std::cout << "findSimilar " << str << " " << nchars << "\n";
    auto it = ngmap.find(key);
    if (it != ngmap.end()) { // key found
      auto set = it->second;
      for (int value : *set) {
        res.push_back(value);
        // std::cout << value << " \n";
      }
    }
    return res;
  }

  void addToResults2(PathSegment *seg, std::string str, int i, int nchars,
                     std::unordered_map<int, Candidate> &candmap) {

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

    // Candidate &cand = candmap[seg->fileId];
    // for (int i = 0; i < cand.v_charscore.size(); i++) {
    // cand.v_charscore[i] = 0;
    // }
  }

  void addToResults(int fid, std::string str, int i, int nchars,
                    std::unordered_map<int, Candidate> &candmap) {

    auto it2 = candmap.find(fid);
    if (it2 == candmap.end()) {
      Candidate cand(fid, strlist[fid], str.size());
      candmap[fid] = cand;
    }

    for (int j = i; j < i + nchars; j++) {
      if (candmap[fid][j] < nchars) {
        candmap[fid].v_charscore[j] = nchars;
      }
    }
  }

  /** @brief Find similar strings for given input str
   *
   * @param[in]  str  String to find in index
   * @param[in]  minChars Minimum substring size to consider in the matching. Set between 2 and 5.
   * Higher time consumption but better results with lower values.
   * @return matches the top 15 strings that most closely resemble the input
   */
  vector<pair<float, int>> findSimilar(std::string str, int minChars) {
    // minChars

    std::unordered_map<int, Candidate> candmap;

    int nchars = 8;
    if (str.size() < nchars) {
      nchars = str.size();
    }

#ifdef _OPENMP
    omp_lock_t writelock;
    omp_init_lock(&writelock);
#endif

    for (; nchars >= minChars; nchars--) {
      int count = str.size() - nchars + 1;
#ifdef _OPENMP
#pragma omp parallel for
#endif
      for (int i = 0; i < count; i++) {
        auto res = findSimilarForNgram(str, i, nchars);
        // std::cout << "i=" << i << " ";
        // int64str(getKeyAtIdx(str, i, nchars), nchars);
        // printVector(res);
        for (const auto &fid : res) {
// std::cout << " " << fid << "(" << strlist[fid] << ") ";
#ifdef _OPENMP
          omp_set_lock(&writelock);
#endif
          addToResults(fid, str, i, nchars, candmap);
#ifdef _OPENMP
          omp_unset_lock(&writelock);
#endif
        }
        // std::cout << " ";
        // std::cout << "\n";
      }
    }

    // 2d array with file id's and scores
    vector<pair<float, int>> results;
    // cout << "cand map size: " << candmap.size() << "\n";
    for (auto &[fid, cand] : candmap) {
      pair<float, int> v;
      float sc = cand.getScore();
      v.first = sc;
      v.second = fid;
      results.push_back(v);
      // cout << "score2: " << v.first;
    }
    // std::sort(results.begin(), results.end());
    // Sort largest score first
    std::sort(results.begin(), results.end(),
              [](pair<float, int> a, pair<float, int> b) { return a.first > b.first; });
    return results;
  }

  void add(std::string str, int fileId) {
    strlist[fileId] = str;
    for (int nchars = 2; nchars <= 8; nchars++) {
      if (str.size() >= nchars) {
        addToIdx(str, fileId, nchars);
      }
    }
  }
};

// StringIndex *idxo;

extern "C" {

void str_idx_free(void *data) {
  // free(data);
  // TODO
}

size_t str_idx_size(const void *data) {
  // TODO: give correct size, although this is not 100% needed
  return sizeof(int);
}

static const rb_data_type_t str_idx_type = {
    .wrap_struct_name = "foo",
    .function =
        {
            .dmark = NULL,
            .dfree = str_idx_free,
            .dsize = str_idx_size,
        },
    .data = NULL,
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
};

VALUE str_idx_alloc(VALUE self) {
  /* allocate */
  // void* data = malloc(10*sizeof(int));

  // StringIndex* ind = new StringIndex();
  void *data = new StringIndex();

  /* wrap */
  return TypedData_Wrap_Struct(self, &str_idx_type, data);
}

VALUE str_idx_m_initialize(VALUE self) { return self; }

void *add_to_idx_slow(void *_data) {

  void **data = (void **)_data;
  StringIndex *idx = (StringIndex *)(data[0]);
  std::string *str = (std::string *)(data[1]);
  int *fid = (int *)(data[2]);

  idx->add(*str, *fid);
  return 0;
}

VALUE StringIndexAddToIndex(VALUE self, VALUE str, VALUE fileId) {
  VALUE ret;
  ret = rb_float_new(5.5);
  std::string s1 = StringValueCStr(str);
  int fid = NUM2INT(fileId);

  void *data;
  TypedData_Get_Struct(self, int, &str_idx_type, data);
  // StringIndex * idx = (StringIndex *) data;

  void **params = (void **)malloc(sizeof(void *) * 5);
  params[0] = data;
  params[1] = &s1;
  params[2] = &fid;
  // rb_thread_call_without_gvl(add_to_idx_slow, params, NULL, NULL);
  // free(params);

  ((StringIndex *)data)->add(s1, fid);

  return ret;
}

VALUE StringIndexAddSegments(VALUE self, VALUE str, VALUE fileId) {
  VALUE ret;
  ret = rb_float_new(5.5);
  std::string s1 = StringValueCStr(str);
  int fid = NUM2INT(fileId);

  void *data;
  TypedData_Get_Struct(self, int, &str_idx_type, data);
  ((StringIndex *)data)->addSegments(s1, fid, '/');

  return ret;
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
  printf("Init_stridx4\n");

  VALUE cFoo = rb_define_class("CppStringIndex", rb_cObject);

  rb_define_alloc_func(cFoo, str_idx_alloc);
  rb_define_method(cFoo, "initialize", str_idx_m_initialize, 0);
  // rb_define_method(cFoo, "add", StringIndexAddToIndex, 2);
  // rb_define_method(cFoo, "add2", StringIndexAddSegments, 2);
  rb_define_method(cFoo, "add", StringIndexAddSegments, 2);

  rb_define_method(cFoo, "find", StringIndexFind, 2);

  // StringIndex idx;
  // idx.addSegments("/foo/b\\ar/sdf\\ sdfsdf/baz.txt", 2, '/');
  // idx.addSegments("/foo/bar/sdfsdfsdf/baz.txt", 2, '/');
  // idx.addSegments("/foo/bar/0dfsdfsdf/zaz.txt", 3, '/');
}

} // End extern "C"
