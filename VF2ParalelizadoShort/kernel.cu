const static int maxv = 10;
const static int maxe = 22;
const int MAX_GRAPHS_DB = 196;
const int MAX_GRAPHS_QUERY = 20;
const int NBLOCKS = 5, NTHREADS = 20;

#include "head.h"
#include "class.h"
#include "signature.h"

#define swap(A,B) { float temp = A; A = B; B = temp;}

const char *QueryPath[MAX_GRAPHS_QUERY]; // Query file path vector
int QueryPathPointer[MAX_GRAPHS_QUERY];
int DBGraphSize, QueryGraphSize, QueryPathSize;

Graph DBGraph[MAX_GRAPHS_DB], QueryGraph[MAX_GRAPHS_QUERY], *vec;

__device__
int contador = 0;
unsigned int matches[MAX_GRAPHS_QUERY];

void init()
{
	ofstream fout;
	fout.open("time.txt");
	fout.close();
	memset(matches, 0, MAX_GRAPHS_QUERY * sizeof(int));
}

string dataset() {
	string dbPath = "Data/db/Q10.min.data";
	QueryPathSize = 0;

	QueryPath[QueryPathSize] = "Data/query/Q4.min.my";
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
	int n = -1;
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
			n++;
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

		DBGraph[i].vtx  = vec[i].vtx;
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

		QueryGraph[i].vtx  = vec[i].vtx;
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

Graph* alocaGraph(Graph *Grafo, int GraphSize) {
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
bool FinalCheck(const State &s, Graph &pat, Graph &g)
{
	for (int i = 0;i < pat.en;i++)
	{
		Edge e1 = pat.edge[i];
		bool flag = 0;

		for (int j = g.head[s.core1[e1.u]];~j;j = g.edge[j].next)
		{
			Edge e2 = g.edge[j];

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
void CalDFSVec(const State &s, VetAuxiliares &vetAux, Graph &pat, Graph &g)
{
	ClearArrays(vetAux);

	for (int i = 0; i < s.TAM;i++) {
		vetAux.m1[vetAux.sizeM1++] = s.first[i];
		vetAux.m2[vetAux.sizeM2++] = s.second[i];
	}

	if (vetAux.sizeM1 > 0 && vetAux.sizeM2 > 0) {
		quicksort(vetAux.m1, 0, vetAux.sizeM1 - 1);
		quicksort(vetAux.m2, 0, vetAux.sizeM2 - 1);
	}

	for (int i = 0; i < pat.vn; i++) {
		if (s.out1[i])
			vetAux.tout1[vetAux.sizeTout1++] = i;
		if (s.in1[i]) {
			vetAux.tin1[vetAux.sizeTin1++] = i;
		}
		vetAux.n1[vetAux.sizeN1++] = i;
	}

	for (int i = 0; i < g.vn; i++) {
		if (s.out2[i])
			vetAux.tout2[vetAux.sizeTout2++] = i;
		if (s.in2[i])
			vetAux.tin2[vetAux.sizeTin2++] = i;
		vetAux.n2[vetAux.sizeN2++] = i;
	}

	vetAux.sizeT1 = Union(vetAux.tin1, vetAux.tout1, vetAux.t1, vetAux.sizeTin1, vetAux.sizeTout1);

	vetAux.sizeT2 = Union(vetAux.tin1, vetAux.tout2, vetAux.t2, vetAux.sizeTin1, vetAux.sizeTout2);

	int tmp[maxv], sizeTmp;

	sizeTmp = Difference(vetAux.n1, vetAux.m1, tmp, vetAux.sizeN1, vetAux.sizeM1);

	vetAux.sizeNS1 = Difference(tmp, vetAux.t1, vetAux.ns1, sizeTmp, vetAux.sizeT1);

	sizeTmp = Difference(vetAux.n2, vetAux.m2, tmp, vetAux.sizeN2, vetAux.sizeM2);

	vetAux.sizeNS2 = Difference(tmp, vetAux.t2, vetAux.ns2, sizeTmp, vetAux.sizeT2);
}

__device__
bool check(const State &s, int a, int b, VetAuxiliares &vetAux, Graph &pat, Graph &g, Graph &revpat, Graph &revg)
{
	// Check vertex label
	if (pat.vtx[a].label != g.vtx[b].label) return 0;

	// Check edge label
	CalCheckVec(a, b, vetAux, pat, g, revpat, revg);

	// Feasibility
	if (CheckPrev(s, a, b, vetAux) && CheckSucc(s, a, b, vetAux) && CheckIn(vetAux) && CheckOut(vetAux) && CheckNew(vetAux)) return 1;

	return 0;
}

__device__
int GenPairs(const State &s, int *&allPairsFirst, int *&allPairsSecond, VetAuxiliares &vetAux, Graph &pat, Graph &g)
{
	int sizeAllPairs = 0;

	CalDFSVec(s, vetAux, pat, g);

	if (vetAux.sizeTout1 > 0 && vetAux.sizeTout2 > 0) {
		allPairsFirst = (int*)malloc(vetAux.sizeTout1 * vetAux.sizeTout2 * sizeof(int));
		allPairsSecond = (int*)malloc(vetAux.sizeTout1 * vetAux.sizeTout2 * sizeof(int));
	}

	for (int i = 0; i < (int)vetAux.sizeTout1; i++)
		for (int j = 0; j < (int)vetAux.sizeTout2; j++) {
			allPairsFirst[sizeAllPairs] = vetAux.tout1[i], allPairsSecond[sizeAllPairs++] = vetAux.tout2[j];
		}

	if (sizeAllPairs > 0)
	{
		return sizeAllPairs;
	}

	if (vetAux.sizeTin1 > 0 && vetAux.sizeTin2 > 0) {
		allPairsFirst = (int*)malloc(vetAux.sizeTin1 * vetAux.sizeTin2 * sizeof(int));
		allPairsSecond = (int*)malloc(vetAux.sizeTin1 * vetAux.sizeTin2 * sizeof(int));
	}

	for (int i = 0; i < (int)vetAux.sizeTin1; i++)
		for (int j = 0; j < (int)vetAux.sizeTin2; j++) {
			allPairsFirst[sizeAllPairs] = vetAux.tin1[i], allPairsSecond[sizeAllPairs++] = vetAux.tin2[j];
		}

	if (sizeAllPairs > 0)
	{
		return sizeAllPairs;
	}

	int temp1[maxv], temp2[maxv];
	int sizeTemp1 = 0, sizeTemp2 = 0;

	for (int i = 0; i < pat.vn; i++)
		if (s.core1[i] == -1)
			temp1[sizeTemp1++] = i;
	
	for (int i = 0; i < g.vn; i++)
		if (s.core2[i] == -1)
			temp2[sizeTemp2++] = i;

	allPairsFirst = (int*)malloc(sizeTemp1 * sizeTemp2 * sizeof(int));
	allPairsSecond = (int*)malloc(sizeTemp1 * sizeTemp2 * sizeof(int));

	for (int i = 0; i < sizeTemp1; i++)
		for (int j = 0; j < sizeTemp2; j++) {
			allPairsFirst[sizeAllPairs] = temp1[i], allPairsSecond[sizeAllPairs++] = temp2[j];
		}

	return sizeAllPairs;	
}
__device__
int CheckPairs(const State &s, int *&allPairsFirst, int *&allPairsSecond, int *&candiPairsFirst, int *&candiPairsSecond, int sizeAllPairs, VetAuxiliares &vetAux, Graph &pat, Graph &g, Graph &revpat, Graph &revg)
{
	int sizeCandiPairs = 0;

	candiPairsFirst = (int*)malloc(sizeAllPairs * sizeof(int));
	candiPairsSecond = (int*)malloc(sizeAllPairs * sizeof(int));

	for (int i = 0; i < sizeAllPairs; i++) {
		if (check(s, allPairsFirst[i], allPairsSecond[i], vetAux, pat, g, revpat, revg)) {
			candiPairsFirst[sizeCandiPairs] = allPairsFirst[i];
			candiPairsSecond[sizeCandiPairs++] = allPairsSecond[i];
		}
	}

	return sizeCandiPairs;
}
__device__
void UpdateState(State &s, int a, int b, Graph &pat, Graph &g, Graph &revpat, Graph &revg)
{
	// Update core,in,out
	for (int i = 0; i < pat.vn; i++)
	{
		s.core1[a] = b;
		s.in1[a] = 0;
		s.out1[a] = 0;
	}
	for (int i = 0; i < g.vn; i++)
	{
		s.core2[b] = a;
		s.in2[b] = 0;
		s.out2[b] = 0;
	}

	for (int i = pat.head[a]; ~i; i = pat.edge[i].next)
	{
		int v = pat.edge[i].v;
		if (s.core1[v] == -1)
			s.out1[v] = 1;
	}
	// Add new in1
	for (int i = revpat.head[a]; ~i; i = revpat.edge[i].next)
	{
		int v = revpat.edge[i].v;
		if (s.core1[v] == -1)
			s.in1[v] = 1;
	}
	// Add new out2
	for (int i = g.head[b]; ~i; i = g.edge[i].next)
	{
		int v = g.edge[i].v;
		if (s.core2[v] == -1)
			s.out2[v] = 1;
	}
	// Add new in2
	for (int i = revg.head[b]; ~i; i = revg.edge[i].next)
	{
		int v = revg.edge[i].v;
		if (s.core2[v] == -1)
			s.in2[v] = 1;
	}

	// Add to s	
	s.first[s.TAM] = a;
	s.second[s.TAM] = b;
	s.TAM++;
}

__device__
bool CheckPrev(const State &s, int a, int b, VetAuxiliares &vetAux)
{
	int tmp[maxv], sizeTmp;
	bool flag;

	sizeTmp = Intersection(vetAux.m1, vetAux.pred1, tmp, vetAux.sizeM1, vetAux.sizePred1);

	for (int i = 0; i < sizeTmp;i++)
	{
		flag = 0;
		for (int j = 0;j < vetAux.sizePred2 && !flag;j++)
			if (s.core1[tmp[i]] == vetAux.pred2[j])
			{
				flag = 1;
			}
		if (!flag) return 0;
	}

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;

	sizeTmp = Intersection(vetAux.m2, vetAux.pred2, tmp, vetAux.sizeM1, vetAux.sizePred2);

	for (int i = 0;i < sizeTmp;i++)
	{
		flag = 0;
		for (int j = 0;j < vetAux.sizePred1 && !flag;j++)
			if (s.core2[tmp[i]] == vetAux.pred1[j])
			{
				flag = 1;
			}
		if (!flag) return 0;
	}

	return 1;
}
__device__
bool CheckSucc(const State &s, int a, int b, VetAuxiliares &vetAux)
{
	int tmp[maxv], sizeTmp;
	bool flag;

	sizeTmp = Intersection(vetAux.m1, vetAux.succ1, tmp, vetAux.sizeM1, vetAux.sizeSucc1);

	for (int i = 0;i < sizeTmp;i++)
	{
		flag = 0;
		for (int j = 0; j < vetAux.sizeSucc2 && !flag;j++)
			if (s.core1[tmp[i]] == vetAux.succ2[j])
			{
				flag = 1;
			}
		if (!flag) return 0;
	}

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;

	sizeTmp = Intersection(vetAux.m2, vetAux.succ2, tmp, vetAux.sizeM2, vetAux.sizeSucc2);

	for (int i = 0;i < sizeTmp;i++)
	{
		flag = 0;
		for (int j = 0;j < vetAux.sizeSucc1 && !flag;j++)
			if (s.core2[tmp[i]] == vetAux.succ1[j])
			{
				flag = 1;
			}
		if (!flag) return 0;
	}

	return 1;
}
__device__
bool CheckIn(VetAuxiliares &vetAux)
{
	int tmp[maxv], sizeTmp;
	int a, b, c, d;

	sizeTmp = Intersection(vetAux.succ1, vetAux.tin1, tmp, vetAux.sizeSucc1, vetAux.sizeTin1);

	a = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;

	sizeTmp = Intersection(vetAux.succ2, vetAux.tin2, tmp, vetAux.sizeSucc2, vetAux.sizeTin2);

	b = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;

	sizeTmp = Intersection(vetAux.pred1, vetAux.tin1, tmp, vetAux.sizePred1, vetAux.sizeTin1);

	c = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;
	sizeTmp = Intersection(vetAux.pred2, vetAux.tin2, tmp, vetAux.sizePred2, vetAux.sizeTin2);

	d = sizeTmp;

	return (a <= b) && (c <= d);
}
__device__
bool CheckOut(VetAuxiliares &vetAux)
{
	int tmp[maxv], sizeTmp;
	int a, b, c, d;

	sizeTmp = Intersection(vetAux.succ1, vetAux.tout1, tmp, vetAux.sizeSucc1, vetAux.sizeTout1);

	a = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;
	sizeTmp = Intersection(vetAux.succ2, vetAux.tout2, tmp, vetAux.sizeSucc2, vetAux.sizeTout2);
	b = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;
	sizeTmp = Intersection(vetAux.pred1, vetAux.tout1, tmp, vetAux.sizePred1, vetAux.sizeTout1);
	c = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;
	sizeTmp = Intersection(vetAux.pred2, vetAux.tout2, tmp, vetAux.sizePred2, vetAux.sizeTout2);
	d = sizeTmp;

	return (a <= b) && (c <= d);
}
__device__
bool CheckNew(VetAuxiliares &vetAux)
{
	int tmp[maxv], sizeTmp;
	int a, b, c, d;

	sizeTmp = Intersection(vetAux.ns1, vetAux.pred1, tmp, vetAux.sizeNS1, vetAux.sizePred1);
	a = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;
	sizeTmp = Intersection(vetAux.ns2, vetAux.pred2, tmp, vetAux.sizeNS2, vetAux.sizePred2);
	b = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;
	sizeTmp = Intersection(vetAux.ns1, vetAux.succ1, tmp, vetAux.sizeNS1, vetAux.sizeSucc1);
	c = sizeTmp;

	//clear tmp
	for (int i = 0;i < maxv;i++) tmp[i] = 0;
	sizeTmp = Intersection(vetAux.ns2, vetAux.succ2, tmp, vetAux.sizeNS2, vetAux.sizeSucc2);
	d = sizeTmp;

	return (a <= b) && (c <= d);
}

__device__
void CalCheckVec(int a, int b, VetAuxiliares &vetAux, Graph &pat, Graph &g, Graph &revpat, Graph &revg)
{
	// Init
	vetAux.sizePred1 = 0, vetAux.sizePred2 = 0, vetAux.sizeSucc1 = 0, vetAux.sizeSucc2 = 0;

	// aPred
	for (int i = revpat.head[a]; ~i; i = revpat.edge[i].next)
		vetAux.pred1[vetAux.sizePred1++] = revpat.edge[i].v;

	// bPred
	for (int i = revg.head[b]; ~i; i = revg.edge[i].next)
		vetAux.pred2[vetAux.sizePred2++] = revg.edge[i].v;

	// aSucc
	for (int i = pat.head[a]; ~i; i = pat.edge[i].next)
		vetAux.succ1[vetAux.sizeSucc1++] = pat.edge[i].v;

	// bSucc
	for (int i = g.head[b]; ~i; i = g.edge[i].next)
		vetAux.succ2[vetAux.sizeSucc2++] = g.edge[i].v;

	// Sort
	if (vetAux.sizePred1 > 0) quicksort(vetAux.pred1, 0, vetAux.sizePred1 - 1);
	if (vetAux.sizePred2 > 0) quicksort(vetAux.pred2, 0, vetAux.sizePred2 - 1);
	if (vetAux.sizeSucc1 > 0) quicksort(vetAux.succ1, 0, vetAux.sizeSucc1 - 1);
	if (vetAux.sizeSucc2 > 0) quicksort(vetAux.succ2, 0, vetAux.sizeSucc2 - 1);
}

__device__
bool dfs(const State &s, VetAuxiliares &vetAux, Graph &pat, Graph &g, Graph &revpat, Graph &revg)
{
	int *allPairsFirst, *allPairsSecond;
	int *candiPairsFirst, *candiPairsSecond;
	
	// Matched
	if ((int)s.TAM == pat.vn)
	{		
		if (FinalCheck(s, pat, g))
		{
			return 1;
		}		
	}

	// Generate Pair(n,m)
	int sizeAllPairs = GenPairs(s, allPairsFirst, allPairsSecond, vetAux, pat, g);
	// Check allPairs, get candiPairs
	int sizeCandiPairs = CheckPairs(s, allPairsFirst, allPairsSecond, candiPairsFirst, candiPairsSecond, sizeAllPairs, vetAux, pat, g, revpat, revg);

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
	
	for (int i = 0;i < sizeVec;i++)
	{
		State ns = s;

		int a = vecFirst[i], b = vecSecond[i];
		
		UpdateState(ns, a, b, pat, g, revpat, revg);

		memcpy(m1t, vetAux.m1, maxv * sizeof(int));
		memcpy(m2t, vetAux.m2, maxv * sizeof(int));

		memcpy(tin1t, vetAux.tin1, maxv * sizeof(int));
		memcpy(tin2t, vetAux.tin2, maxv * sizeof(int));

		memcpy(tout1t, vetAux.tout1, maxv * sizeof(int));
		memcpy(tout2t, vetAux.tout2, maxv * sizeof(int));

		memcpy(n1t, vetAux.n1, maxv * sizeof(int));
		memcpy(n2t, vetAux.n2, maxv * sizeof(int));

		memcpy(ns1t, vetAux.ns1, maxv * sizeof(int));
		memcpy(ns2t, vetAux.ns2, maxv * sizeof(int));

		memcpy(t1t, vetAux.t1, maxv * sizeof(int));
		memcpy(t2t, vetAux.t2, maxv * sizeof(int));
		
		ret = dfs(ns, vetAux, pat, g, revpat, revg);		

		memcpy(vetAux.m1, m1t, maxv * sizeof(int));
		memcpy(vetAux.m2, m2t, maxv * sizeof(int));

		memcpy(vetAux.tin1, tin1t, maxv * sizeof(int));
		memcpy(vetAux.tin2, tin2t, maxv * sizeof(int));

		memcpy(vetAux.tout1, tout1t, maxv * sizeof(int));
		memcpy(vetAux.tout2, tout2t, maxv * sizeof(int));

		memcpy(vetAux.n1, n1t, maxv * sizeof(int));
		memcpy(vetAux.n2, n2t, maxv * sizeof(int));

		memcpy(vetAux.ns1, ns1t, maxv * sizeof(int));
		memcpy(vetAux.ns2, ns2t, maxv * sizeof(int));

		memcpy(vetAux.t1, t1t, maxv * sizeof(int));
		memcpy(vetAux.t2, t2t, maxv * sizeof(int));

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
bool query(const State &s, VetAuxiliares &vetAux, Graph &pat, Graph &g, Graph &revpat, Graph &revg)
{
	return dfs(s, vetAux, pat, g, revpat, revg);
}
__device__
Graph copyGraph(Graph &graphSource) {
	Graph graphDest;
	graphDest.aloca();

	graphSource.en = graphDest.en;
	graphSource.vn = graphDest.vn;

	for (int j = 0; j < graphSource.en;j++) {
		graphDest.edge[j] = graphSource.edge[j];
		graphDest.head[j] = graphSource.head[j];
	}

	for (int j = 0; j < graphSource.vn;j++) {
		graphDest.vtx[j] = graphSource.vtx[j];
	}

	return graphDest;
}


__global__
void solve(Graph *QueryGraph, Graph *DBGraph, char *QueryPath, int *QueryPathPointer, int sizeQuery, int sizeDB, int sizeQueryP, unsigned int *dev_matches)
{
	int x, result;
	int controle[NBLOCKS * NTHREADS];

	memset(controle, 0, NBLOCKS * NTHREADS * sizeof(int));

	if (threadIdx.x == 0 && blockIdx.x == 0) {
		printf("Processando...\nThreads %d Blocks %d Modelos %d Grafos %d Arquivos %d\n", NTHREADS, NBLOCKS, sizeDB, sizeQuery, sizeQueryP);
	}

	/*printf(" QueryGraph \n");
	printGraph(QueryGraph, sizeQuery);
	printf("\n\n\n DBGraph \n\n\n");
	printGraph(DBGraph, sizeDB);*/

	for (int i = 0;i < (int)sizeQueryP;i++)
	{
		int init = threadIdx.x + blockIdx.x * blockDim.x;
		
		while(controle[init] < sizeQuery){
			int j = controle[init];

			if (init >= sizeDB)
				continue;

			Graph pat, g, revpat, revg;
			State s;
			s.init();	

			VetAuxiliares vetAux;
			
			pat.aloca();
			pat.en = QueryGraph[j].en;
			pat.vn = QueryGraph[j].vn;

			for (int k = 0; k < QueryGraph[j].en;k++) {
				pat.edge[k] = QueryGraph[j].edge[k];
				pat.head[k] = QueryGraph[j].head[k];
			}

			for (int k = 0; k < QueryGraph[j].vn;k++) {
				pat.vtx[k] = QueryGraph[j].vtx[k];
			}

			GenRevGraph(pat, revpat);
			
			result = 0;
			for (x = init; x < sizeDB; x+= NTHREADS * NBLOCKS)
			{
				g.aloca();
				g.en = DBGraph[x].en;
				g.vn = DBGraph[x].vn;

				for (int k = 0; k < DBGraph[x].en;k++) {
					g.edge[k] = DBGraph[x].edge[k];
					g.head[k] = DBGraph[x].head[k];
				}

				for (int k = 0; k < DBGraph[x].vn;k++) {
					g.vtx[k] = DBGraph[x].vtx[k];
				}

				//printf("x => %d pat.vn %d g.vn %d pat.en %d g.en %d \n", x, pat.vn, g.vn, pat.en, g.en);

				if (pat.vn > g.vn || pat.en > g.en) continue;

				GenRevGraph(g, revg);
				
				if (query(s, vetAux, pat, g, revpat, revg)) // Matched
				{
					atomicAdd(&dev_matches[j], 1);
				}

				free(g.head);
				free(g.vtx);
				free(g.edge);
			}

			controle[init]++;

			free(pat.head);
			free(pat.vtx);
			free(pat.edge);
		}		
	}
}

void cudaShowLimit() {
	size_t limit = 0;

	if (cudaDeviceGetLimit(&limit, cudaLimitStackSize) != cudaSuccess) {
		printf("ERROR: Não foi possível retornar o limite do stack\n");
	}
	//printf("cudaLimitStackSize: %u\n", (unsigned)limit);

	if (cudaDeviceGetLimit(&limit, cudaLimitPrintfFifoSize) != cudaSuccess) {
		printf("ERROR: Não foi possível retornar o limite do FIFO\n");
	}
	//printf("cudaLimitPrintfFifoSize: %u\n", (unsigned)limit);

	if (cudaDeviceGetLimit(&limit, cudaLimitMallocHeapSize) != cudaSuccess) {
		printf("ERROR: Não foi possível retornar o limite do HEAP\n");
	}	
	//printf("cudaLimitMallocHeapSize: %u\n", (unsigned)limit);

	limit = 1024 * 64;

	cudaDeviceSetLimit(cudaLimitStackSize, limit);	
	//cudaDeviceSetLimit(cudaLimitPrintfFifoSize, limit);

	limit = 1024 * 1024 * 1024;
	//cudaDeviceSetLimit(cudaLimitMallocHeapSize, limit);

	limit = 0;

	cudaDeviceGetLimit(&limit, cudaLimitStackSize);
	//printf("New cudaLimitStackSize: %u\n", (unsigned)limit);
	cudaDeviceGetLimit(&limit, cudaLimitPrintfFifoSize);
	//printf("New cudaLimitPrintfFifoSize: %u\n", (unsigned)limit);
	cudaDeviceGetLimit(&limit, cudaLimitMallocHeapSize);
	//printf("New cudaLimitMallocHeapSize: %u\n", (unsigned)limit);
}

void beforeSolve() {
	Graph *DBGraphCUDA, *QueryGraphCUDA;
	char *QueryPathCUDA;
	int *QueryPathPointerCUDA;
	unsigned int *MatchesCUDA;
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
	cudaStatus = cudaMemcpy(QueryPathPointerCUDA, QueryPathPointer, (sizeof(int) * MAX_GRAPHS_QUERY), cudaMemcpyHostToDevice);

	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "QueryPathPointerCUDA h->d cudaMemcpy failed!");
		goto Error;
	}

	cudaMalloc((void **)&MatchesCUDA, MAX_GRAPHS_QUERY * sizeof(int));
	cudaStatus = cudaMemcpy(MatchesCUDA, matches, (sizeof(int) * MAX_GRAPHS_QUERY), cudaMemcpyHostToDevice);

	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "MatchesCUDA h-> d cudaMemcpy failed!");
		goto Error;
	}

	solve << <NBLOCKS, NTHREADS >> > (QueryGraphCUDA, DBGraphCUDA, QueryPathCUDA, QueryPathPointerCUDA, QueryGraphSize, DBGraphSize, QueryPathSize, MatchesCUDA);
	
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching addKernel!\n", cudaStatus);
		goto Error;
	}

	cudaStatus = cudaMemcpy(matches, MatchesCUDA, MAX_GRAPHS_QUERY * sizeof(int), cudaMemcpyDeviceToHost);
	
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "MatchesCUDA d->h cudaMemcpy failed!");
		goto Error;
	}

	for(int j=0; j < QueryPathSize;j++)
		for (int i = 0; i < QueryGraphSize;i++) {
			printf("%s %d Matches found %d \n", QueryPath[j], i, matches[i]);
		}


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
__device__
void ClearArrays(VetAuxiliares &vetAux) {
	for (int i = 0; i < maxv;i++) {
		vetAux.m1[i] = 0, vetAux.m2[i] = 0;
		vetAux.tin1[i] = 0, vetAux.tin2[i] = 0;
		vetAux.tout1[i] = 0, vetAux.tout2[i] = 0;
		vetAux.n1[i] = 0, vetAux.n2[i] = 0;
		vetAux.ns1[i] = 0, vetAux.ns2[i] = 0;
		vetAux.t1[i] = 0, vetAux.t2[i] = 0;
	}

	vetAux.sizeM1 = 0, vetAux.sizeM2 = 0;
	vetAux.sizeTin1 = 0, vetAux.sizeTin2 = 0;
	vetAux.sizeTout1 = 0, vetAux.sizeTout2 = 0;
	vetAux.sizeN1 = 0, vetAux.sizeN2 = 0;
	vetAux.sizeNS1 = 0, vetAux.sizeNS2 = 0;
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