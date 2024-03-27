
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

#include "unordered_dense.h"

using std::cout;
using std::pair;
using std::string;
using std::vector;

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

// Candidate for result in string (filename) search
class Candidate {
public:
  std::vector<int> v_charscore;
  int fileId;
  int len;
  float minscore;
  float maxscore;

  // The string that this candidate represents
  string str;

  Candidate(){};
  Candidate(int _fileId, string _str, int _len) : fileId(_fileId), str(_str), len(_len) {
    // Initialize v_charscores with zeros
    v_charscore.resize(len, 0);
  }

  float getScore() {
    int i = 0;
    float score = 0.0;
    for (int &charscore : v_charscore) {
      score += charscore;
      i++;
    }
    float div = len * len;
    float div2 = len * str.size();
    float score1 = score / div;
    float score2 = score / div2;
    score = score1 * 0.97 + score2 * 0.03;
    return score;
  }

  int operator[](int idx) { return v_charscore[idx]; }
  //TODO: all

};

std::string int64str(int64_t ngram, int nchars) {

  std::string res = "";
  int64_t x;
  int multip = nchars * 8;
  for (int i = 0; i <= nchars; i++) {
    char c = (ngram >> multip) & 255;
    // std::cout << c;
    multip -= 8;
    res.push_back(c);
  }
  return res;
}


// This seems to give 10x speed improvement over std::unordered_map
typedef ankerl::unordered_dense::map<int64_t, std::set<int> * > HashMap;
// typedef std::unordered_map<int64_t, std::set<int> *> HashMap;

class StringIndex {
public:
  int tmp;

  std::unordered_map<int64_t, int> ng3map;
  std::unordered_map<int64_t, std::set<int> *> ng3map2;
  std::vector<HashMap *> ngmaps;

  std::unordered_map<int, std::string> strlist;

  StringIndex() {

    for (int i = 0; i <= 8; i++) {
      ngmaps.push_back(new HashMap);
    }
    
    // for (auto const& [key, val] : map) {
        // std::cout << key << " => " << val << std::endl;
    // }
    
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
      // std::string t = s1.substr(i, nchars);
      // int64_t key = 0;
      // for (int i_char = 0; i_char < nchars; i_char++) {
        // key = key | static_cast<int>(t[i_char]);
        // if (i_char < nchars - 1) {
          // // Shift 8 bits to the left except on the last iteration
          // key = key << 8;
        // }
      // }
      // std::cout << "key: " << int64ToBinaryString(key) << "\n";
      int64_t key = getKeyAtIdx(s1,i,nchars);

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

  vector<pair<float, int>> findSimilar(std::string str) {

    std::unordered_map<int, Candidate> candmap;

    int nchars = 8;
    if (str.size() < nchars) {
      nchars = str.size();
    }

    for (; nchars >= 3; nchars--) {
      // std::cout << "nchars=" << nchars << "\n";
      for (int i = 0; i + nchars <= str.size(); i++) {
        auto res = findSimilarForNgram(str, i, nchars);
        // std::cout << "i=" << i << " ";
        // int64str(getKeyAtIdx(str, i, nchars), nchars);
        // printVector(res);
        for (const auto &fid : res) {
          // std::cout << " " << fid << "(" << strlist[fid] << ") ";
          addToResults(fid, str, i, nchars, candmap);
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

StringIndex *idxo;

extern "C" {
VALUE addToIndex(VALUE self, VALUE str, VALUE fileId) {
  VALUE ret;
  ret = rb_float_new(5.5);
  std::string s1 = StringValueCStr(str);
  int fid = NUM2INT(fileId);
  idxo->add(s1, fid);
  return ret;
}

VALUE str_idx_debug(VALUE self) {
  VALUE ret;
  ret = rb_float_new(0);
  idxo->dumpStatus();
  return ret;
}

VALUE str_idx_find_similar(VALUE self, VALUE str) {
  VALUE ret;
  std::string s1 = StringValueCStr(str);

  ret = rb_ary_new();
  const vector<pair<float, int>> &results = idxo->findSimilar(s1);
  int limit = 15;
  int i=0;
  for (const auto &res : results) {
  	VALUE arr = rb_ary_new();
    rb_ary_push(arr,INT2NUM(res.second));
    rb_ary_push(arr,DBL2NUM(res.first));
    rb_ary_push(ret,arr);
    i++;
    if (i >= limit) {break;}
  }
  return ret;
}

void Init_stridx(void) {
  printf("Init_stridx\n");
  std::vector<int> vect(10, 0); // size 10 with values initialized to 0
  vect[0] = 5;
  std::cout << vect[0] << std::endl;
  idxo = new StringIndex();
  rb_define_global_function("str_idx_addToIndex", addToIndex, 2);
  rb_define_global_function("str_idx_debug", str_idx_debug, 0);
  rb_define_global_function("str_idx_find_similar", str_idx_find_similar, 1);
}

} // End extern "C"
