struct Vertex
{
	int id;
	int label;
	__device__ __host__
		Vertex(int _id = 0, int _label = 0) : id(_id), label(_label) {}
	__device__ __host__
		~Vertex() {}
};

struct Edge
{
	int u;
	int v;
	int label;
	int next;

	__device__ __host__
		Edge(int _u = 0, int _v = 0, int _label = 0, int _next = -1) : u(_u), v(_v), label(_label), next(_next) {}
	__device__ __host__
		bool operator == (const Edge &o) const
	{
		return u == o.u&&v == o.v&&label == o.label;
	}
	__device__ __host__
		~Edge() {}
};

struct Graph
{
public:
	__device__ __host__
		Graph()
	{
		
	}
	__device__ __host__
		~Graph() {
		
	}
	__device__ __host__
		void aloca() {
			head = (int*)malloc(maxe * sizeof(int));
			vtx = (Vertex*)malloc(maxv * sizeof(Vertex));
			edge = (Edge*)malloc(maxe * sizeof(Edge));

			init();
		}
	__device__ __host__
		void init() {		

		memset(head, -1, maxe * sizeof(int));
		vn = 0;
		en = 0;
	}
	__device__ __host__
		void addv(int id, int label) {
		vtx[id] = Vertex(id, label);
		vn++;
	}
	__device__ __host__
		void addse(int u, int v, int label) {		
		edge[en] = Edge(u, v, label, head[u]);
		head[u] = en++;
	}
	__device__ __host__
		void adde(int u, int v, int label) {
		addse(u, v, label);
		addse(v, u, label);
	}

public:
	int *head;
	int vn;
	int en;
	Vertex *vtx; // 0 to vn-1
	Edge *edge; // 0 to en-1
};
struct VetAuxiliares
{
	int pred1[maxv], pred2[maxv], succ1[maxv], succ2[maxv], m1[maxv], m2[maxv], tin1[maxv], tin2[maxv];
	int tout1[maxv], tout2[maxv], n1[maxv], n2[maxv], ns1[maxv], ns2[maxv], t1[maxv], t2[maxv];
	int sizeM1 = 0, sizeM2 = 0, sizeN1 = 0, sizeN2 = 0, sizeNS1 = 0, sizeNS2 = 0, sizeT1 = 0, sizeT2 = 0, sizeTout1 = 0, sizeTout2 = 0;
	int sizePred1 = 0, sizePred2 = 0, sizeSucc1 = 0, sizeSucc2 = 0, sizeTin1 = 0, sizeTin2 = 0;
};


struct State // State of dfs matching
{
	// Same means with the paper
	short int first[maxv];
	short int second[maxv];
	short int TAM;
	short int core1[maxv];
	short int core2[maxv];
	short int in1[maxv];
	short int in2[maxv];
	short int out1[maxv];
	short int out2[maxv];
	__device__
	State()
	{
		
	}
	__device__
	~State()
	{

	}
	__device__
	void init() {
		TAM = 0;
		memset(core1, -1, maxv * sizeof(short int));
		memset(core2, -1, maxv * sizeof(short int));
		memset(in1, 0, maxv * sizeof(short int));
		memset(in2, 0, maxv * sizeof(short int));
		memset(out1, 0, maxv * sizeof(short int));
		memset(out2, 0, maxv * sizeof(short int));
	}
};