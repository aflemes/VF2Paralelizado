const static int maxv = 10;
const static int maxe = 20;
const int MAX_GRAPHS_DB = 1;
const int MAX_GRAPHS_QUERY = 4;
const int NBLOCKS = 1, NTHREADS = 2;

#include "head.h"
#include "class.h"
#include "signature.h"

#define swap(A,B) { float temp = A; A = B; B = temp;}


const char *QueryPath[MAX_GRAPHS_QUERY]; // Query file path vector
int QueryPathPointer[MAX_GRAPHS_QUERY];
int DBGraphSize, QueryGraphSize, QueryPathSize;

Graph DBGraph[MAX_GRAPHS_DB], QueryGraph[MAX_GRAPHS_QUERY], *vec;

__device__
int pred1[maxv], pred2[maxv],succ1[maxv], succ2[maxv],m1[maxv], m2[maxv], tin1[maxv], tin2[maxv];
__device__
int tout1[maxv], tout2[maxv],n1[maxv], n2[maxv], ns1[maxv], ns2[maxv], t1[maxv], t2[maxv];
__device__
int sizeM1 = 0, sizeM2 = 0, sizeN1 = 0, sizeN2 = 0, sizeNS1 = 0, sizeNS2 = 0, sizeT1 = 0, sizeT2 = 0, sizeTout1 = 0, sizeTout2 = 0;
__device__
int sizePred1 = 0, sizePred2 = 0, sizeSucc1 = 0, sizeSucc2 = 0, sizeTin1 = 0, sizeTin2 = 0;;
__device__
int sizeAllPairs, sizeCandiPairs;

__device__
Graph pat[NTHREADS], g[NTHREADS], revpat[NTHREADS], revg[NTHREADS];
__device__
int contador = 0;


void init()
{
	ofstream fout;
	fout.open("time.txt");
	fout.close();
}

string dataset() {
	string dbPath = "Data/Q10e10.min.data";
	QueryPathSize = 0;

	QueryPath[QueryPathSize] = "Data/Q4.min.my";
	QueryPathPointer[QueryPathSize] = strlen(QueryPath[QueryPathSize]);
	QueryPathSize++;

	return dbPath;
}

void ReadFile(string path, int &graphSize, int MAX_GRAPHS)
{
	bool eof = false;
	graphSize = 0;

	ifstream fin;
	fin.open(path.c_str());

	vec = (Graph*)malloc(MAX_GRAPHS * sizeof(Graph));
	vec[graphSize].aloca();

	string buff;
	int n;
	int m, l;
	int p, q;
	while (getline(fin, buff))
	{

		if (buff.size() == 0) continue;
		if (buff == "t # -1")
		{
			eof = true;
			graphSize++;			
			break;
		}
		if (buff[0] == 't')
		{
			sscanf_s(buff.c_str(), "t # %d", &n);
			if (n == 0) continue;

			graphSize++;
			vec[graphSize].aloca();
		}
		else if (buff[0] == 'v')
		{
			sscanf_s(buff.c_str(), "v %d %d", &m, &l);
			vec[graphSize].addv(m, l);
		}
		else if (buff[0] == 'e')
		{
			sscanf_s(buff.c_str(), "e %d %d %d", &p, &q, &l);
			vec[graphSize].adde(p, q, l);

		}
		else puts("Error!");
	}

	if (!eof)
		printf("Nao foi encontrado o fim do arquivo (t #-1) \n");

	fin.close();
}

void ReadDB(string path)
{
	ReadFile(path, DBGraphSize, MAX_GRAPHS_DB);

	for (int i = 0; i < DBGraphSize;i++) {
		DBGraph[i].en = vec[i].en;
		DBGraph[i].vn = vec[i].vn;

		DBGraph[i].vtx = vec[i].vtx;
		DBGraph[i].edge = vec[i].edge;
		DBGraph[i].head = vec[i].head;
	}
}

void ReadQuery(string path)
{
	ReadFile(path, QueryGraphSize, MAX_GRAPHS_QUERY);

	for (int i = 0; i < QueryGraphSize;i++) {
		QueryGraph[i].en = vec[i].en;
		QueryGraph[i].vn = vec[i].vn;

		QueryGraph[i].vtx = vec[i].vtx;
		QueryGraph[i].edge = vec[i].edge;
		QueryGraph[i].head = vec[i].head;

	}

}
__device__
void GenRevGraph(const Graph &src, Graph &dst)
{
	dst = Graph();
	dst.aloca();

	for (int i = 0; i < src.vn; i++)
		dst.addv(src.vtx[i].id, src.vtx[i].label);

	for (int i = 0; i < src.en; i++)
		dst.addse(src.edge[i].v, src.edge[i].u, src.edge[i].label);
}

void input()
{
	// Standard data set
	string dbPath = dataset();

	string tt = "Output/ans";
	for (int i = 0;i < (int)QueryPathSize;i++) {
		ReadQuery(QueryPath[i]);
	}

	ReadDB(dbPath);
	puts("Read Data Finished!");
}

char* allocaString(const char **str, int size) {
	char *localCUDA, *a;
	int TAM = 0;

	//aloca
	for (int i = 0;i < QueryPathSize;i++)
		TAM += QueryPathPointer[i];

	a = (char *)malloc(TAM * sizeof(char));

	//flatten
	int subidx = 0;
	for (int i = 0;i < QueryPathSize;i++)
	{
		for (int j = 0; j < QueryPathPointer[i]; j++)
			a[subidx++] = QueryPath[i][j];
	}

	cudaMalloc((void **)&localCUDA, TAM * sizeof(char));
	cudaMemcpy(localCUDA, a, TAM * sizeof(char), cudaMemcpyHostToDevice);

	return localCUDA;
}

Graph* alocaGraph(Graph Grafo[MAX_GRAPHS_DB], int GraphSize) {
	Graph *GraphHost, *GraphCUDA;

	GraphHost = (Graph*)malloc(GraphSize * sizeof(Graph));

	for (int k = 0;k < GraphSize;k++) {
		Vertex *vtx;
		Edge *edge;
		int *head;

		if (cudaMalloc((void **)&vtx, Grafo[k].vn * sizeof(Vertex)) != cudaSuccess) {
			printf("ERROR: Não foi possível alocar os vertices \n");
		}
		if (cudaMalloc((void **)&edge, Grafo[k].en * sizeof(Edge)) != cudaSuccess) {
			printf("ERROR: Não foi possível alocar os vertices \n");
		}
		if (cudaMalloc((void **)&head, maxe * sizeof(int)) != cudaSuccess) {
			printf("ERROR: Não foi possível alocar o head \n");
		}

		if (cudaMemcpy(vtx, Grafo[k].vtx, Grafo[k].vn * sizeof(Vertex), cudaMemcpyHostToDevice) != cudaSuccess) {
			printf("ERROR: Não foi possível copiar os vertices \n");
		}

		if (cudaMemcpy(edge, Grafo[k].edge, Grafo[k].en * sizeof(Edge), cudaMemcpyHostToDevice) != cudaSuccess) {
			printf("ERROR: Não foi possível copiar as arestas \n");
		}

		if (cudaMemcpy(head, Grafo[k].head, maxe * sizeof(int), cudaMemcpyHostToDevice) != cudaSuccess) {
			printf("ERROR: Não foi possível copiar o head \n");
		}

		GraphHost[k].vtx = vtx;
		GraphHost[k].edge = edge;
		GraphHost[k].head = head;
		GraphHost[k].en = Grafo[k].en;
		GraphHost[k].vn = Grafo[k].vn;
	}

	cudaMalloc((void **)&GraphCUDA, GraphSize * sizeof(Graph));
	cudaMemcpy(GraphCUDA, GraphHost, (sizeof(Graph) * GraphSize), cudaMemcpyHostToDevice);

	return GraphCUDA;
}

__device__
bool FinalCheck(const State &s, const int threadId)
{
	for (int i = 0;i < pat[threadId].en;i++)
	{
		Edge e1 = pat[threadId].edge[i];
		bool flag = 0;

		for (int j = g[threadId].head[s.core1[e1.u]];~j;j = g[threadId].edge[j].next)
		{
			Edge e2 = g[threadId].edge[j];

			if (e1.label == e2.label&&s.core1[e1.v] == e2.v)
			{
				flag = 1;
				break;
			}
		}
		if (!flag) return 0;
	}
	return 1;
}
__device__
void CalDFSVec(const State &s, const int threadId)
{
	//printf("CalDFSVec %d \n", s.TAM);
	ClearArrays();

	for (int i = 0; i < s.TAM;i++) {
		m1[sizeM1++] = s.first[i];
		m2[sizeM2++] = s.second[i];
	}

	//printf("CalDFSVec antes quicksort %d %d\n", sizeM1, sizeM2);

	if (sizeM1 > 0 && sizeM2 > 0) {
		quicksort(m1, 0, sizeM1 - 1);
		quicksort(m2, 0, sizeM2 - 1);
	}

	//printf("CalDFSVec antes pat.vn %d\n", pat.vn);

	for (int i = 0; i < pat[threadId].vn; i++) {
		if (s.out1[i])
			tout1[sizeTout1++] = i;
		if (s.in1[i]) {
			tin1[sizeTin1++] = i;
		}
		n1[sizeN1++] = i;
	}

	//printf("CalDFSVec antes g.vn %d\n", g.vn);

	for (int i = 0; i < g[threadId].vn; i++) {
		if (s.out2[i])
			tout2[sizeTout2++] = i;
		if (s.in2[i])
			tin2[sizeTin2++] = i;
		n2[sizeN2++] = i;
	}

	//printf("CalDFSVec antes metodos \n");

	sizeT1 = Union(tin1, tout1, t1, sizeTin1, sizeTout1);

	sizeT2 = Union(tin1, tout2, t2, sizeTin1, sizeTout2);

	int tmp[maxv], sizeTmp;

	sizeTmp = Difference(n1, m1, tmp, sizeN1, sizeM1);

	sizeNS1 = Difference(tmp, t1, ns1, sizeTmp, sizeT1);

	sizeTmp = Difference(n2, m2, tmp, sizeN2, sizeM2);

	sizeNS2 = Difference(tmp, t2, ns2, sizeTmp, sizeT2);

	//printf("fim CalDFSVec \n");
}

__device__
bool check(const State &s, int a, int b, const int threadId)
{
	//printf("check \n");
	// Check vertex label
	if (pat[threadId].vtx[a].label != g[threadId].vtx[b].label) return 0;

	// Check edge label
	CalCheckVec(s, a, b, threadId);

	// Feasibility
	if (CheckPrev(s, a, b) && CheckSucc(s, a, b) && CheckIn(s) && CheckOut(s) && CheckNew(s)) return 1;
	return 0;
}

__device__
void GenPairs(const State &s, int *&allPairsFirst, int *&allPairsSecond, const int threadId)
{
	//printf("GenPairs \n");

	CalDFSVec(s, threadId);

	if (sizeTout1 > 0 && sizeTout2 > 0) {
		allPairsFirst = (int*)malloc(sizeTout1 * sizeTout2 * sizeof(int));
		allPairsSecond = (int*)malloc(sizeTout1 * sizeTout2 * sizeof(int));
	}

	for (int i = 0; i < (int)sizeTout1; i++)
		for (int j = 0; j < (int)sizeTout2; j++) {
			allPairsFirst[sizeAllPairs] = tout1[i], allPairsSecond[sizeAllPairs++] = tout2[j];
		}

	//printf("1 -> sizeAllPairs %d \n", sizeAllPairs);
	if (sizeAllPairs > 0)
	{
		return;
	}

	if (sizeTin1 > 0 && sizeTin2 > 0) {
		allPairsFirst = (int*)malloc(sizeTin1 * sizeTin2 * sizeof(int));
		allPairsSecond = (int*)malloc(sizeTin1 * sizeTin2 * sizeof(int));
	}

	for (int i = 0; i < (int)sizeTin1; i++)
		for (int j = 0; j < (int)sizeTin2; j++) {
			allPairsFirst[sizeAllPairs] = tin1[i], allPairsSecond[sizeAllPairs++] = tin2[j];
		}

	//printf("2 -> sizeAllPairs %d \n", sizeAllPairs);
	if (sizeAllPairs > 0)
	{
		return;
	}

	int temp1[maxv], temp2[maxv];
	int sizeTemp1 = 0, sizeTemp2 = 0;

	for (int i = 0; i < pat[threadId].vn; i++)
		if (s.core1[i] == -1)
			temp1[sizeTemp1++] = i;
	
	for (int i = 0; i < g[threadId].vn; i++)
		if (s.core2[i] == -1)
			temp2[sizeTemp2++] = i;

	allPairsFirst = (int*)malloc(sizeTemp1 * sizeTemp2 * sizeof(int));
	allPairsSecond = (int*)malloc(sizeTemp1 * sizeTemp2 * sizeof(int));

	for (int i = 0; i < sizeTemp1; i++)
		for (int j = 0; j < sizeTemp2; j++) {
			allPairsFirst[sizeAllPairs] = temp1[i], allPairsSecond[sizeAllPairs++] = temp2[j];
		}

	//printf("fim GenPairs %d \n", sizeAllPairs);
}
__device__
void CheckPairs(const State &s, int *&allPairsFirst, int *&allPairsSecond, int *&candiPairsFirst, int *&candiPairsSecond, const int threadId)
{
	//printf("CheckPairs \n");
	sizeCandiPairs = 0;

	candiPairsFirst = (int*)malloc(sizeAllPairs * sizeof(int));
	candiPairsSecond = (int*)malloc(sizeAllPairs * sizeof(int));

	for (int i = 0; i < sizeAllPairs; i++) {
		if (check(s, allPairsFirst[i], allPairsSecond[i], threadId)) {
			candiPairsFirst[sizeCandiPairs] = allPairsFirst[i];
			candiPairsSecond[sizeCandiPairs++] = allPairsSecond[i];
		}
	}

	//printf("fim CheckPairs %d \n", sizeCandiPairs);
}
__device__
void UpdateState(State &s, int a, int b, const int threadId)
{
		// Update core,in,out
	for (int i = 0; i < pat[threadId].vn; i++)
	{
		s.core1[a] = b;
		s.in1[a] = 0;
		s.out1[a] = 0;
	}
	for (int i = 0; i < g[threadId].vn; i++)
	{
		s.core2[b] = a;
		s.in2[b] = 0;
		s.out2[b] = 0;
	}

	for (int i = pat[threadId].head[a]; ~i; i = pat[threadId].edge[i].next)
	{
		int v = pat[threadId].edge[i].v;
		if (s.core1[v] == -1)
			s.out1[v] = 1;
	}
	// Add new in1
	for (int i = revpat[threadId].head[a]; ~i; i = revpat[threadId].edge[i].next)
	{
		int v = revpat[threadId].edge[i].v;
		if (s.core1[v] == -1)
			s.in1[v] = 1;
	}
	// Add new out2
	for (int i = g[threadId].head[b]; ~i; i = g[threadId].edge[i].next)
	{
		int v = g[threadId].edge[i].v;
		if (s.core2[v] == -1)
			s.out2[v] = 1;
	}
	// Add new in2
	for (int i = revg[threadId].head[b]; ~i; i = revg[threadId].edge[i].next)
	{
		int v = revg[threadId].edge[i].v;
		if (s.core2[v] == -1)
			s.in2[v] = 1;
	}

	// Add to s	
	s.first[s.TAM] = a;
	s.second[s.TAM] = b;
	s.TAM++;
}

__device__
bool CheckPrev(const State &s, int a, int b)
{
	int tmp[maxv], sizeTmp;
	bool flag;

	sizeTmp = Intersection(m1, pred1, tmp, sizeM1, sizePred1);

	for (int i = 0; i < sizeTmp;i++)
	{
		flag = 0;
		for (int j = 0;j < sizePred2 && !flag;j++)
			if (s.core1[tmp[i]] == pred2[j])
			{
				flag = 1;
			}
		if (!flag) return 0;
	}

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;

	sizeTmp = Intersection(m2, pred2, tmp, sizeM1, sizePred2);

	for (int i = 0;i < sizeTmp;i++)
	{
		flag = 0;
		for (int j = 0;j < sizePred1 && !flag;j++)
			if (s.core2[tmp[i]] == pred1[j])
			{
				flag = 1;
			}
		if (!flag) return 0;
	}

	return 1;
}
__device__
bool CheckSucc(const State &s, int a, int b)
{
	int tmp[maxv], sizeTmp;
	bool flag;

	sizeTmp = Intersection(m1, succ1, tmp, sizeM1, sizeSucc1);

	for (int i = 0;i < sizeTmp;i++)
	{
		flag = 0;
		for (int j = 0; j < sizeSucc2 && !flag;j++)
			if (s.core1[tmp[i]] == succ2[j])
			{
				flag = 1;
			}
		if (!flag) return 0;
	}

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;

	sizeTmp = Intersection(m2, succ2, tmp, sizeM2, sizeSucc2);

	for (int i = 0;i < sizeTmp;i++)
	{
		flag = 0;
		for (int j = 0;j < sizeSucc1 && !flag;j++)
			if (s.core2[tmp[i]] == succ1[j])
			{
				flag = 1;
			}
		if (!flag) return 0;
	}

	return 1;
}
__device__
bool CheckIn(const State &s)
{
	int tmp[maxv], sizeTmp;
	int a, b, c, d;

	sizeTmp = Intersection(succ1, tin1, tmp, sizeSucc1, sizeTin1);

	a = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;

	sizeTmp = Intersection(succ2, tin2, tmp, sizeSucc2, sizeTin2);

	b = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;

	sizeTmp = Intersection(pred1, tin1, tmp, sizePred1, sizeTin1);

	c = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;
	sizeTmp = Intersection(pred2, tin2, tmp, sizePred2, sizeTin2);

	d = sizeTmp;

	return (a <= b) && (c <= d);
}
__device__
bool CheckOut(const State &s)
{
	int tmp[maxv], sizeTmp;
	int a, b, c, d;

	sizeTmp = Intersection(succ1, tout1, tmp, sizeSucc1, sizeTout1);

	a = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;
	sizeTmp = Intersection(succ2, tout2, tmp, sizeSucc2, sizeTout2);
	b = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;
	sizeTmp = Intersection(pred1, tout1, tmp, sizePred1, sizeTout1);
	c = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;
	sizeTmp = Intersection(pred2, tout2, tmp, sizePred2, sizeTout2);
	d = sizeTmp;

	return (a <= b) && (c <= d);
}
__device__
bool CheckNew(const State &s)
{
	int tmp[maxv], sizeTmp;
	int a, b, c, d;

	sizeTmp = Intersection(ns1, pred1, tmp, sizeNS1, sizePred1);
	a = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;
	sizeTmp = Intersection(ns2, pred2, tmp, sizeNS2, sizePred2);
	b = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;
	sizeTmp = Intersection(ns1, succ1, tmp, sizeNS1, sizeSucc1);
	c = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;
	sizeTmp = Intersection(ns2, succ2, tmp, sizeNS2, sizeSucc2);
	d = sizeTmp;

	return (a <= b) && (c <= d);
}

__device__
void CalCheckVec(const State &s, int a, int b, const int threadId)
{
	//printf("CalCheckVec \n");
	// Init
	sizePred1 = 0, sizePred2 = 0, sizeSucc1 = 0, sizeSucc2 = 0;

	// aPred
	for (int i = revpat[threadId].head[a]; ~i; i = revpat[threadId].edge[i].next)
		pred1[sizePred1++] = revpat[threadId].edge[i].v;

	// bPred
	for (int i = revg[threadId].head[b]; ~i; i = revg[threadId].edge[i].next)
		pred2[sizePred2++] = revg[threadId].edge[i].v;

	// aSucc
	for (int i = pat[threadId].head[a]; ~i; i = pat[threadId].edge[i].next)
		succ1[sizeSucc1++] = pat[threadId].edge[i].v;

	// bSucc
	for (int i = g[threadId].head[b]; ~i; i = g[threadId].edge[i].next)
		succ2[sizeSucc2++] = g[threadId].edge[i].v;

	//printf("antes sort %d %d %d %d\n", sizePred1, sizePred2, sizeSucc1, sizeSucc2);
	//printf(" antes sort => %d %d \n",sizePred1, pred1[0]);
	// Sort
	if (sizePred1 > 0) quicksort(pred1, 0, sizePred1 - 1);
	//printf("a \n");
	if (sizePred2 > 0) quicksort(pred2, 0, sizePred2 - 1);
	//printf("b \n");
	if (sizeSucc1 > 0) quicksort(succ1, 0, sizeSucc1 - 1);
	//printf("c \n");
	if (sizeSucc2 > 0) quicksort(succ2, 0, sizeSucc2 - 1);

	//printf("fim CalCheckVec \n");
}
__device__
void quicksort(int ls[], int l, int r) {
	int i, j, k, p, q;
	int v;
	if (r <= l)
		return;
	v = ls[r];
	i = l - 1;
	j = r;
	p = l - 1;
	q = r;
	for (;;) {
		while (ls[++i] < v);
		while (v < ls[--j])
			if (j == l)
				break;
		if (i >= j)
			break;
		swap(ls[i], ls[j]);
		if (ls[i] == v) {
			p++;
			swap(ls[p], ls[i]);
		}
		if (v == ls[j]) {
			q--;
			swap(ls[q], ls[j]);
		}
	}
	swap(ls[i], ls[r]);
	j = i - 1;
	i++;
	for (k = l; k < p; k++, j--)
		swap(ls[k], ls[j]);
	for (k = r - 1; k > q; k--, i++)
		swap(ls[k], ls[i]);

	quicksort(ls, l, j);
	quicksort(ls, i, r);
}
__device__
int Union(int arr1[], int arr2[], int arr3[], int m, int n)
{
	int i = 0, j = 0, x = 0;

	while (i < m && j < n) {
		if (arr1[i] < arr2[j]) {
			arr3[x++] = arr1[i++];
		}
		else
			if (arr2[j] < arr1[i]) {
				arr3[x++] = arr2[j++];
			}
			else {
				arr3[x++] = arr2[j++];
				i++;
			}
	}

	/* Print remaining elements of the larger array */
	while (i < m)
		arr3[x++] = arr1[i++];
	while (j < n)
		arr3[x++] = arr2[j++];

	return x;
}
__device__
int Difference(int arr1[], int arr2[], int arr3[], int n1, int n2)
{
	int i = 0, j = 0, k = 0, x = 0;
	while (i < n1 && j < n2) {

		// If not common, print smaller 
		if (arr1[i] < arr2[j]) {
			arr3[x++] = arr1[i++];
			k++;
		}
		else
			if (arr2[j] < arr1[i]) {
				j++;
				k++;
			}
		// Skip common element 
			else {
				i++;
				j++;
			}
	}

	// printing remaining elements 
	while (i < n1) {

		arr3[x++] = arr1[i++];
		k++;
	}
	while (j < n2) {
		arr2[x++] = arr1[j++];
		k++;
	}

	return x;
}
__device__
int Intersection(int arr1[], int arr2[], int arr3[], int n1, int n2)
{
	int i = 0, j = 0, k = 0, x = 0;
	while (i < n1 && j < n2) {

		// If not common, jump
		if (arr1[i] < arr2[j]) {
			i++, k++;
		}
		else
			if (arr2[j] < arr1[i]) {
				j++, k++;
			}
			else {
				arr3[x++] = arr1[i++];
				j++;
			}
	}

	return x;
}
__device__
void ClearArrays() {
	//printf("ClearArrays\n");

	for (int i = 0; i < maxv;i++) {
		m1[i] = 0, m2[i] = 0;
		tin1[i] = 0, tin2[i] = 0;
		tout1[i] = 0, tout2[i] = 0;
		n1[i] = 0, n2[i] = 0;
		ns1[i] = 0, ns2[i] = 0;
		t1[i] = 0, t2[i] = 0;
	}

	sizeM1 = 0, sizeM2 = 0;
	sizeTin1 = 0, sizeTin2 = 0;
	sizeTout1 = 0, sizeTout2 = 0;
	sizeN1 = 0, sizeN2 = 0;
	sizeNS1 = 0, sizeNS2 = 0;
	sizeAllPairs = 0;

	//printf("fim ClearArrays");
}

__device__
bool dfs(const State &s, const int threadId)
{
	int *allPairsFirst, *allPairsSecond;
	int *candiPairsFirst, *candiPairsSecond;

	printf("threadId %d contador %d ref s => %d\n", threadId, contador, &s);

	contador++;

	// Matched
	//printf("s.TAM %d pat.vn %d \n", s.TAM, pat[threadId].vn);
	if ((int)s.TAM == pat[threadId].vn)
	{		
		if (FinalCheck(s, threadId))
		{
			return 1;
		}		
	}

	// Generate Pair(n,m)
	GenPairs(s, allPairsFirst, allPairsSecond, threadId);
	// Check allPairs, get candiPairs
	CheckPairs(s, allPairsFirst, allPairsSecond, candiPairsFirst, candiPairsSecond, threadId);

	// For tmp dfs store
	int *vecFirst, *vecSecond;
	int sizeVec = sizeCandiPairs;
	int m1t[maxv], m2t[maxv];
	int tin1t[maxv], tin2t[maxv];
	int tout1t[maxv], tout2t[maxv];
	int n1t[maxv], n2t[maxv];
	int ns1t[maxv], ns2t[maxv];
	int t1t[maxv], t2t[maxv];

	vecFirst = (int*)malloc(sizeCandiPairs * sizeof(int));
	vecSecond = (int*)malloc(sizeCandiPairs * sizeof(int));

	memcpy(vecFirst, candiPairsFirst, sizeCandiPairs * sizeof(int));
	memcpy(vecSecond, candiPairsSecond, sizeCandiPairs * sizeof(int));

	bool ret = false;
	//printf("threadId %d sizeVec %d \n", threadId, sizeVec);
	// Next recursive	
	for (int i = 0;i < sizeVec;i++)
	{
		State ns = s;
		int a = vecFirst[i], b = vecSecond[i];
		
		UpdateState(ns, a, b, threadId);

		memcpy(m1t, m1, maxv * sizeof(int));
		memcpy(m2t, m2, maxv * sizeof(int));

		memcpy(tin1t, tin1, maxv * sizeof(int));
		memcpy(tin2t, tin2, maxv * sizeof(int));

		memcpy(tout1t, tout1, maxv * sizeof(int));
		memcpy(tout2t, tout2, maxv * sizeof(int));

		memcpy(n1t, n1, maxv * sizeof(int));
		memcpy(n2t, n2, maxv * sizeof(int));

		memcpy(ns1t, ns1, maxv * sizeof(int));
		memcpy(ns2t, ns2, maxv * sizeof(int));

		memcpy(t1t, t1, maxv * sizeof(int));
		memcpy(t2t, t2, maxv * sizeof(int));

		ret = dfs(ns, threadId);

		memcpy(m1, m1t, maxv * sizeof(int));
		memcpy(m2, m2t, maxv * sizeof(int));

		memcpy(tin1, tin1t, maxv * sizeof(int));
		memcpy(tin2, tin2t, maxv * sizeof(int));

		memcpy(tout1, tout1t, maxv * sizeof(int));
		memcpy(tout2, tout2t, maxv * sizeof(int));

		memcpy(n1, n1t, maxv * sizeof(int));
		memcpy(n2, n2t, maxv * sizeof(int));

		memcpy(ns1, ns1t, maxv * sizeof(int));
		memcpy(ns2, ns2t, maxv * sizeof(int));

		memcpy(t1, t1t, maxv * sizeof(int));
		memcpy(t2, t2t, maxv * sizeof(int));

		if (ret) break;
	}

	free(allPairsFirst);
	free(allPairsSecond);
	free(candiPairsFirst);
	free(candiPairsSecond);
	free(vecFirst);
	free(vecSecond);

	if (ret)
		return 1;
	else return 0;
}

__device__
bool query(const int threadId, const State &s)
{
	//printf("Referencia s => %d \n", &s);

	return dfs(s, threadId);
}

__global__
void solve(Graph *QueryGraph, Graph *DBGraph, char *QueryPath, int *QueryPathPointer, int sizeQuery, int sizeDB, int sizeQueryP)
{
	int matches = 0;
	State s[NTHREADS];

	if (threadIdx.x == 0)
		printf("Processando qtde modelos %d qtde grafos %d qtde arquivos %d\n", sizeDB, sizeQuery, sizeQueryP);

	/*printf(" QueryGraph \n");
	printGraph(QueryGraph, sizeQuery);
	printf("\n\n\n DBGraph \n\n\n");
	printGraph(DBGraph, sizeDB);*/

	for (int i = 0;i < (int)sizeQueryP;i++)
	{
		for (int j = threadIdx.x;j < sizeQuery;j += NTHREADS) {
			matches = 0;

			s[threadIdx.x].init();
			

			pat[threadIdx.x] = QueryGraph[j];

			GenRevGraph(pat[threadIdx.x], revpat[threadIdx.x]);

			for (int x = 0; x < sizeDB; x++)
			{
				g[threadIdx.x] = DBGraph[x];

				//printf("pat.vn %d  g.vn %d pat.en %d g.en %d \n", pat.vn, g.vn, pat.en, g.en);
				if (pat[threadIdx.x].vn > g[threadIdx.x].vn || pat[threadIdx.x].en > g[threadIdx.x].en) continue;

				GenRevGraph(g[threadIdx.x], revg[threadIdx.x]);

				if (query(threadIdx.x, s[threadIdx.x])) // Matched
				{
					matches++;
				}
			}
			
			printf("%s %d Matches found %d \n", QueryPath, j , matches);
		}		
	}
}

void cudaShowLimit() {
	size_t limit = 0;

	if (cudaDeviceGetLimit(&limit, cudaLimitStackSize) != cudaSuccess) {
		printf("ERROR: Não foi possível retornar o limite do stack\n");
	}
	printf("cudaLimitStackSize: %u\n", (unsigned)limit);

	if (cudaDeviceGetLimit(&limit, cudaLimitPrintfFifoSize) != cudaSuccess) {
		printf("ERROR: Não foi possível retornar o limite do FIFO\n");
	}
	printf("cudaLimitPrintfFifoSize: %u\n", (unsigned)limit);

	if (cudaDeviceGetLimit(&limit, cudaLimitMallocHeapSize) != cudaSuccess) {
		printf("ERROR: Não foi possível retornar o limite do HEAP\n");
	}	
	printf("cudaLimitMallocHeapSize: %u\n", (unsigned)limit);

	limit = 1024 * 32;

	cudaDeviceSetLimit(cudaLimitStackSize, limit);	
	//cudaDeviceSetLimit(cudaLimitPrintfFifoSize, limit);

	limit = 1024 * 1024 * 1024;
	//cudaDeviceSetLimit(cudaLimitMallocHeapSize, limit);

	limit = 0;

	cudaDeviceGetLimit(&limit, cudaLimitStackSize);
	printf("New cudaLimitStackSize: %u\n", (unsigned)limit);
	cudaDeviceGetLimit(&limit, cudaLimitPrintfFifoSize);
	printf("New cudaLimitPrintfFifoSize: %u\n", (unsigned)limit);
	cudaDeviceGetLimit(&limit, cudaLimitMallocHeapSize);
	printf("New cudaLimitMallocHeapSize: %u\n", (unsigned)limit);
}

void beforeSolve() {
	Graph *DBGraphCUDA, *QueryGraphCUDA;
	char *QueryPathCUDA;
	int *QueryPathPointerCUDA;
	
	cudaError_t cudaStatus;	
	float time;
	cudaEvent_t start, stop;

	cudaEventCreate(&start);
	cudaEventCreate(&stop);
	cudaEventRecord(start, 0);

	cudaShowLimit();

	QueryGraphCUDA = alocaGraph(QueryGraph, QueryGraphSize);
	DBGraphCUDA = alocaGraph(DBGraph, DBGraphSize);
	QueryPathCUDA = allocaString(QueryPath, QueryPathSize);

	cudaMalloc((void **)&QueryPathPointerCUDA, MAX_GRAPHS_QUERY * sizeof(int));
	cudaMemcpy(QueryPathPointerCUDA, QueryPathPointer, (sizeof(int) * MAX_GRAPHS_QUERY), cudaMemcpyHostToDevice);

	solve << <NBLOCKS, NTHREADS >> > (QueryGraphCUDA, DBGraphCUDA, QueryPathCUDA, QueryPathPointerCUDA, QueryGraphSize, DBGraphSize, QueryPathSize);
	
	//is used in host code (i.e. running on the CPU) when it is desired that CPU activity wait on the completion of any pending GPU activity
	//cudaThreadSynchronize();

	cudaEventRecord(stop, 0);
	cudaEventSynchronize(stop);
	cudaEventElapsedTime(&time, start, stop);

	printf("Time elapsed %.2f \n", time);	

	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "addKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error;
	}

Error:
	cudaFree(QueryGraphCUDA);
	cudaFree(DBGraphCUDA);
	cudaFree(QueryPathCUDA);
}

int main()
{
	// 0: no output matching ans, 1: output matching ans
	init();
	input();
	beforeSolve();	
}

__device__
void printGraph(Graph grafo[], int size) {
	for (int i = 0;i < size; i++) {
		printf("Indice %d Graph[i].en %d Graph[i].vn %d => \n",i, grafo[i].en, grafo[i].vn);

		for (int j = 0; j < grafo[i].en;j++) {
			printf("indice %d Edge[j].u %d Edge[j].v %d Edge[j].next %d\n",j, grafo[i].edge[j].u, grafo[i].edge[j].v, grafo[i].edge[j].next);
		}
		for (int j = 0; j < grafo[i].vn;j++) {
			printf("indice %d Vtx[j].id %d Vtx[j].label %d \n",j, grafo[i].vtx[j].id, grafo[i].vtx[j].label);
		}
	}
}