#include <stdio.h>
#include <string.h>
#include <cstdlib>


struct node {
int i;
void * next;
};

void add_to_list(char c, int i, struct node ** t) {
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

float calc_sub_score(char* s1, char* s2, int i1, int i2) {

    int s1_len = strlen(s1);
    int s2_len = strlen(s2);
    int match_count = 1;

    int i_s1 = i1-1;
    //printf("{");
    for (int i_s2=i2-1; i_s2 >= 0 && i_s1 >= 0;) {
        if(s1[i_s1] == s2[i_s2]) {
            //printf("%c",s1[i_s1]);
            i_s1--; i_s2--;
            match_count++;
        }
        else {i_s2--;}
    }

    i_s1 = i1+1;
    //printf("%c",s1[i1]);
    for (int i_s2=i2+1; i_s2 < s2_len && i_s1 < s1_len;) {
        if(s1[i_s1] == s2[i_s2]) {
            //printf("%c",s1[i_s1]);
            i_s1++; i_s2++;
            match_count++;
        }
        else {i_s2++;}
    }


    //printf("}");
    return (float) match_count;

}

float srn_dst(char * s1, char * s2) {
    struct node** t;
    int len_s1 = strlen(s1);
    int len_s2 = strlen(s2);
    t = (struct node**) calloc(256,sizeof(struct node*));
    //t = (struct node*) calloc(l2,sizeof(void*));
    float score=0;
    //printf("l1,2: %d %d\n",len_s1,len_s2);

    for(int i_s2=0;i_s2 < strlen(s2); i_s2++) {
        add_to_list(s2[i_s2],i_s2,t);
    }

    for(int i_s1=0;i_s1 < strlen(s1); i_s1++) {
        if (t[s1[i_s1]]) {
            float max_score = 0;
            char c = s1[i_s1];
            struct node * n = t[s1[i_s1]];
            do {
                float sub_score = calc_sub_score(s1,s2,i_s1,n->i);
                if(sub_score > max_score) {max_score = sub_score;}
                //printf(" i=%d %c %d [%f] \n",i_s1,c,n->i,sub_score);
            } while(n = n->next);
            score += max_score;
        }
    }

    //dump_list(t);
    score = score/(len_s1*len_s1);

    // Free memory
    for(int i=0;i<256;i++) {
        if(t[i]) {
            node * nA = t[i];
            node * nB;
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


