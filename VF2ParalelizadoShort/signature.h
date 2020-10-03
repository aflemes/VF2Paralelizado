#pragma once
/*assinatura de metodos*/
void ReadFile(string path, int &graphSize, int MAX_GRAPHS);
void ReadDB(string path);
void ReadQuery(string path);
void input();
__device__
void printGraph(Graph Graph[], int size);
__device__
bool query(const State &s, VetAuxiliares &vetAux);
__device__
bool dfs(const State &s, VetAuxiliares &vetAux);
__device__
bool FinalCheck(const State &s);
__device__
void CalDFSVec(const State &s, VetAuxiliares &vetAux);
__device__
bool check(const State &s, int a, int b, VetAuxiliares &vetAux);
__device__
int GenPairs(const State &s, int *&allPairsFirst, int *&allPairsSecond, VetAuxiliares &vetAux);
__device__
int CheckPairs(const State &s, int *&allPairsFirst, int *&allPairsSecond, int *&candiPairsFirst, int *&candiPairsSecond, int sizeAllPairs);
__device__
void UpdateState(State &s, int a, int b);
__device__
bool CheckPrev(const State &s, int a, int b, VetAuxiliares &vetAux);
__device__
bool CheckSucc(const State &s, int a, int b, VetAuxiliares &vetAux);
__device__
bool CheckIn(VetAuxiliares &vetAux);
__device__
bool CheckOut(VetAuxiliares &vetAux);
__device__
bool CheckNew(VetAuxiliares &vetAux);
__device__
void CalCheckVec(int a, int b, VetAuxiliares &vetAux);
__device__
void quicksort(int ls[], int l, int r);
__device__
int Union(int arr1[], int arr2[], int arr3[], int m, int n);
__device__
int Difference(int arr1[], int arr2[], int arr3[], int n1, int n2);
__device__
int Intersection(int arr1[], int arr2[], int arr3[], int n1, int n2);
__device__
void ClearArrays();