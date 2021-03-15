#include <ruby.h>
// #include <gtk/gtk.h>
#include "ruby/ruby.h"

#include <stdio.h>
#include <stdlib.h>

typedef struct node {
int i;
void * next;
} node;


void add_to_list(unsigned char c, int i, struct node ** t) {
    struct node * n;
    struct node * np;

    n =(struct node*) calloc(1,sizeof(struct node)); //TODO: free
    n->i = i;
    if(!t[c]) {
        t[c] = n;
    }
    else {
        np = t[c];
        while (np->next) {
            np = np->next;
        }
        np->next = n;
    }
}

void dump_list(struct node**t) {
    for(int i=0;i < 256; i++) {
        if(t[i]) {
            printf ("\n%c: ", (char) i);
            struct node * n = t[i];
            do {
                printf ("%d ", n->i);
            }
            while (n = n->next);
        }
    }
}

float calc_sub_score(unsigned char* s1, unsigned char* s2, int i1, int i2) {

    int s1_len = strlen(s1);
    int s2_len = strlen(s2);
    float sub_score = 1;
    float score_inc = 1;
    float score_inc_multip = 0.63212;
    //float score_inc_multip = 0.23212;


    // From i2 to zero
    int i_s1 = i1-1;
    //printf("{");
    for (int i_s2=i2-1; i_s2 >= 0 && i_s1 >= 0;) {
        if(s1[i_s1] == s2[i_s2]) {
            //printf("%c",s1[i_s1]);
            i_s1--; i_s2--;
            sub_score += score_inc;
            score_inc = 1;
        }
        else {i_s2--; score_inc = score_inc*score_inc_multip;}
    }


    // From i2 to end
    score_inc = 1;
    i_s1 = i1+1;
    //printf("%c",s1[i1]);
    for (int i_s2=i2+1; i_s2 < s2_len && i_s1 < s1_len;) {
        if(s1[i_s1] == s2[i_s2]) {
            //printf("%c",s1[i_s1]);
            i_s1++; i_s2++;
            sub_score += score_inc;
            score_inc = 1;
        }
        else {i_s2++;score_inc = score_inc*score_inc_multip;}
    }


    //printf("}");
    return sub_score;

}

float srn_dst(char * s1_sgn, char * s2_sgn) {
    unsigned char* s1;
    unsigned char* s2;
    s1 = (unsigned char *) s1_sgn;
    s2 = (unsigned char *) s2_sgn;
    struct node** t;
    int len_s1 = strlen(s1);
    int len_s2 = strlen(s2);
    t = (struct node**) calloc(256,sizeof(struct node*));
    float score=0;
    node * nA;
    node * nB;
    //printf("l1,2: %d %d\n",len_s1,len_s2);

    for(int i_s2=0;i_s2 < strlen(s2); i_s2++) {
        add_to_list(s2[i_s2],i_s2,t);
    }

    for(int i_s1=0;i_s1 < strlen(s1); i_s1++) {
        struct node * n = t[s1[i_s1]];
        if (n)  {
            float max_score = 0;
            unsigned char c = s1[i_s1];
            do {
                float sub_score = calc_sub_score(s1,s2,i_s1,n->i);
                if(sub_score > max_score) {max_score = sub_score;}
                //printf(" i=%d %c %d [%f] \n",i_s1,c,n->i,sub_score);
            } while(n = n->next);
            score += max_score;
        }
    }

    //dump_list(t);
    float p =0.01;
    score = (1-p)*score/(len_s1*len_s1) +p*score/(len_s1*len_s2);

    // Free memory
    for(int i=0;i<256;i++) {
        if(t[i]) {
            // node * nA = t[i];
            // node * nB;
            nA = t[i];
            do {
                nB = nA->next;
                free(nA);
                nA = nB;
            } while (nA);
        }
    }
    free(t);

    return score;
}

void srn_dst_wrap(void *y) {
  void **x = (void **)y;
  char *a = (char *)x[0];
  char *b = (char *)x[1];
  float *d = (float *)x[2];
  *d = srn_dst(a, b);
  // printf("00000 A:%s B:%s %f\n",a,b,*d);
}

VALUE _srn_dst(VALUE self, VALUE s1, VALUE s2) {
  VALUE ret;
  float d;
  void **ptr = malloc(sizeof(void *) * 3);
  ptr[0] = (void *)StringValueCStr(s1);
  ptr[1] = (void *)StringValueCStr(s2);
  ptr[2] = (void *)&d;
  rb_thread_call_without_gvl(srn_dst_wrap, ptr, NULL, NULL);
  // d = srn_dst(StringValueCStr(s1), StringValueCStr(s2));
  ret = rb_float_new(d);
  free(ptr);
  return ret;
}

void Init_vmaext(void) {
  printf("Init_vmaext\n");
  rb_define_global_function("srn_dst", _srn_dst, 2);
}


