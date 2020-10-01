struct Vertex
{
	int id;
	int label;
	int seq;
	bool del;
	__device__ __host__
		Vertex(int _id = 0, int _label = 0) : id(_id), label(_label), seq(-1), del(0) {}
	__device__ __host__
		~Vertex() {}
};

struct Edge
{
	int u;
	int v;
	int label;
	int next;
	bool del;

	__device__ __host__
		Edge(int _u = 0, int _v = 0, int _label = 0, int _next = -1) : u(_u), v(_v), label(_label), next(_next), del(0) {}
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
	__device__ __host__
		void delse(int u, int v, int label) {
		for (int i = head[u];~i;i = edge[i].next)
		{
			if (edge[i].u == u && edge[i].v == v && edge[i].label == label)
			{
				edge[i].del = 1;
				return;
			}
		}
	}
	__device__ __host__
		void dele(int u, int v, int label) {
		for (int i = head[u];~i;i = edge[i].next)
		{
			if (edge[i].u == u && edge[i].v == v && edge[i].label == label)
			{
				edge[i].del = 1;
				edge[i ^ 1].del = 1;
				return;
			}
		}
	}

public:
	int *head;	
	int vn;
	int en;
	Vertex *vtx; // 0 to vn-1
	Edge *edge; // 0 to en-1
};
__device__
struct State // State of dfs matching
{
	// Same means with the paper
	short int first[maxv];
	short int second[maxv];
	short int TAM;
	short int core1[maxv];
	short int core2[maxv];
	bool in1[maxv];
	bool in2[maxv];
	bool out1[maxv];
	bool out2[maxv];
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
		/*first = (short int*)malloc(maxv * sizeof(short int));
		second= (short int*)malloc(maxv * sizeof(short int));
		core1 = (short int*)malloc(maxv * sizeof(short int));
		core2 = (short int*)malloc(maxv * sizeof(short int));
		in1 = (bool*)malloc(maxv * sizeof(bool));
		in2 = (bool*)malloc(maxv * sizeof(bool));
		out1= (bool*)malloc(maxv * sizeof(bool));
		out2= (bool*)malloc(maxv * sizeof(bool));*/

		memset(core1, -1, maxv * sizeof(short int));
		memset(core2, -1, maxv * sizeof(short int));
		memset(in1, 0, maxv * sizeof(bool));
		memset(in2, 0, maxv * sizeof(bool));
		memset(out1, 0, maxv * sizeof(bool));
		memset(out2, 0, maxv * sizeof(bool));
	}
};