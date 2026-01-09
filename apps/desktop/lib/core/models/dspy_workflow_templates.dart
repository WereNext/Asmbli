import 'dspy_blocks.dart';
import 'dspy_types.dart';

/// Pre-built DSPy workflow templates
///
/// Each template directly maps to executable DSPy code.
/// No fictional concepts - every block has a real backend implementation.
class DspyWorkflowTemplates {
  DspyWorkflowTemplates._();

  static List<DspyWorkflowTemplate> getAllTemplates() => [
    simpleChainOfThought(),
    treeOfThoughtAnalysis(),
    reactAgentWithTools(),
    ragResearchFlow(),
    codeGenerationFlow(),
    confidenceRoutingFlow(),
  ];

  /// Simple Chain of Thought
  /// Input → ChainOfThought → Output
  ///
  /// Backend: POST /reasoning with pattern=chain_of_thought
  static DspyWorkflowTemplate simpleChainOfThought() {
    final now = DateTime.now();
    return DspyWorkflowTemplate(
      id: 'simple_cot',
      name: 'Simple Chain of Thought',
      description: 'Step-by-step reasoning for straightforward questions',
      category: DspyWorkflowCategory.reasoning,
      tags: ['basic', 'reasoning', 'cot'],
      workflow: DspyWorkflow(
        id: 'simple_cot_workflow',
        name: 'Simple Chain of Thought',
        model: DspyModel.claude3Sonnet,
        blocks: [
          const DspyBlock(
            id: 'input_1',
            type: DspyBlockType.input,
            label: 'Question',
            position: BlockPosition(x: 100, y: 150),
            config: InputBlockConfig(
              variableName: 'question',
              description: 'The question to reason about',
            ),
          ),
          const DspyBlock(
            id: 'cot_1',
            type: DspyBlockType.chainOfThought,
            label: 'Reason Step by Step',
            position: BlockPosition(x: 300, y: 150),
            config: ChainOfThoughtBlockConfig(
              signatureInput: 'question',
              signatureOutput: 'answer',
            ),
          ),
          const DspyBlock(
            id: 'output_1',
            type: DspyBlockType.output,
            label: 'Answer',
            position: BlockPosition(x: 500, y: 150),
            config: OutputBlockConfig(
              variableName: 'answer',
              includeReasoning: true,
            ),
          ),
        ],
        connections: [
          const DspyBlockConnection(
            id: 'conn_1',
            sourceBlockId: 'input_1',
            targetBlockId: 'cot_1',
          ),
          const DspyBlockConnection(
            id: 'conn_2',
            sourceBlockId: 'cot_1',
            targetBlockId: 'output_1',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Tree of Thought Analysis
  /// Input → TreeOfThought → Output
  ///
  /// Backend: POST /reasoning with pattern=tree_of_thought
  static DspyWorkflowTemplate treeOfThoughtAnalysis() {
    final now = DateTime.now();
    return DspyWorkflowTemplate(
      id: 'tot_analysis',
      name: 'Tree of Thought Analysis',
      description: 'Explore multiple approaches and synthesize the best solution',
      category: DspyWorkflowCategory.reasoning,
      tags: ['advanced', 'reasoning', 'tot', 'multi-approach'],
      workflow: DspyWorkflow(
        id: 'tot_analysis_workflow',
        name: 'Tree of Thought Analysis',
        model: DspyModel.claude3Sonnet,
        blocks: [
          const DspyBlock(
            id: 'input_1',
            type: DspyBlockType.input,
            label: 'Problem',
            position: BlockPosition(x: 100, y: 150),
            config: InputBlockConfig(
              variableName: 'problem',
              description: 'The problem requiring multi-approach analysis',
            ),
          ),
          const DspyBlock(
            id: 'tot_1',
            type: DspyBlockType.treeOfThought,
            label: 'Explore Approaches',
            position: BlockPosition(x: 300, y: 150),
            config: TreeOfThoughtBlockConfig(
              numBranches: 3,
              approaches: [
                'straightforward solution',
                'creative approach',
                'robust and scalable solution',
              ],
            ),
          ),
          const DspyBlock(
            id: 'output_1',
            type: DspyBlockType.output,
            label: 'Best Solution',
            position: BlockPosition(x: 520, y: 150),
            config: OutputBlockConfig(
              variableName: 'final_answer',
              includeReasoning: true,
            ),
          ),
        ],
        connections: [
          const DspyBlockConnection(
            id: 'conn_1',
            sourceBlockId: 'input_1',
            targetBlockId: 'tot_1',
          ),
          const DspyBlockConnection(
            id: 'conn_2',
            sourceBlockId: 'tot_1',
            targetBlockId: 'output_1',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// ReAct Agent with Tools
  /// Input → ReActAgent (with calculator, json_parser) → Output
  ///
  /// Backend: POST /agent/execute
  static DspyWorkflowTemplate reactAgentWithTools() {
    final now = DateTime.now();
    return DspyWorkflowTemplate(
      id: 'react_tools',
      name: 'ReAct Agent with Tools',
      description: 'Tool-using agent that reasons and acts to complete tasks',
      category: DspyWorkflowCategory.agent,
      tags: ['agent', 'tools', 'react', 'task-completion'],
      workflow: DspyWorkflow(
        id: 'react_tools_workflow',
        name: 'ReAct Agent with Tools',
        model: DspyModel.claude3Sonnet,
        blocks: [
          const DspyBlock(
            id: 'input_1',
            type: DspyBlockType.input,
            label: 'Task',
            position: BlockPosition(x: 100, y: 150),
            config: InputBlockConfig(
              variableName: 'task',
              description: 'The task for the agent to complete',
            ),
          ),
          const DspyBlock(
            id: 'tool_calc',
            type: DspyBlockType.tool,
            label: 'Calculator',
            position: BlockPosition(x: 300, y: 80),
            config: ToolBlockConfig(
              toolName: 'calculator',
              toolType: DspyToolType.calculator,
            ),
          ),
          const DspyBlock(
            id: 'tool_json',
            type: DspyBlockType.tool,
            label: 'JSON Parser',
            position: BlockPosition(x: 300, y: 220),
            config: ToolBlockConfig(
              toolName: 'json_parser',
              toolType: DspyToolType.jsonParser,
            ),
          ),
          const DspyBlock(
            id: 'react_1',
            type: DspyBlockType.reactAgent,
            label: 'ReAct Agent',
            position: BlockPosition(x: 500, y: 150),
            config: ReActBlockConfig(
              maxIterations: 5,
              toolIds: ['calculator', 'json_parser'],
            ),
          ),
          const DspyBlock(
            id: 'output_1',
            type: DspyBlockType.output,
            label: 'Result',
            position: BlockPosition(x: 720, y: 150),
            config: OutputBlockConfig(
              variableName: 'answer',
              includeReasoning: true,
            ),
          ),
        ],
        connections: [
          const DspyBlockConnection(
            id: 'conn_1',
            sourceBlockId: 'input_1',
            targetBlockId: 'react_1',
          ),
          const DspyBlockConnection(
            id: 'conn_2',
            sourceBlockId: 'tool_calc',
            targetBlockId: 'react_1',
            sourcePin: 'tool',
            targetPin: 'tools',
          ),
          const DspyBlockConnection(
            id: 'conn_3',
            sourceBlockId: 'tool_json',
            targetBlockId: 'react_1',
            sourcePin: 'tool',
            targetPin: 'tools',
          ),
          const DspyBlockConnection(
            id: 'conn_4',
            sourceBlockId: 'react_1',
            targetBlockId: 'output_1',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// RAG Research Flow
  /// Input → RAGQuery → ChainOfThought → Output
  ///
  /// Backend: POST /rag/query then POST /reasoning
  static DspyWorkflowTemplate ragResearchFlow() {
    final now = DateTime.now();
    return DspyWorkflowTemplate(
      id: 'rag_research',
      name: 'RAG Research Flow',
      description: 'Retrieve documents and generate well-sourced answers',
      category: DspyWorkflowCategory.rag,
      tags: ['rag', 'research', 'documents', 'citations'],
      workflow: DspyWorkflow(
        id: 'rag_research_workflow',
        name: 'RAG Research Flow',
        model: DspyModel.claude3Sonnet,
        blocks: [
          const DspyBlock(
            id: 'input_1',
            type: DspyBlockType.input,
            label: 'Research Question',
            position: BlockPosition(x: 100, y: 150),
            config: InputBlockConfig(
              variableName: 'question',
              description: 'The research question to answer',
            ),
          ),
          const DspyBlock(
            id: 'rag_1',
            type: DspyBlockType.ragQuery,
            label: 'Retrieve Documents',
            position: BlockPosition(x: 300, y: 150),
            config: RAGBlockConfig(
              numPassages: 5,
              includeCitations: true,
            ),
          ),
          const DspyBlock(
            id: 'cot_1',
            type: DspyBlockType.chainOfThought,
            label: 'Synthesize Answer',
            position: BlockPosition(x: 500, y: 150),
            config: ChainOfThoughtBlockConfig(
              signatureInput: 'context, question',
              signatureOutput: 'answer',
            ),
          ),
          const DspyBlock(
            id: 'output_1',
            type: DspyBlockType.output,
            label: 'Research Answer',
            position: BlockPosition(x: 700, y: 150),
            config: OutputBlockConfig(
              variableName: 'answer',
              includeReasoning: true,
            ),
          ),
        ],
        connections: [
          const DspyBlockConnection(
            id: 'conn_1',
            sourceBlockId: 'input_1',
            targetBlockId: 'rag_1',
          ),
          const DspyBlockConnection(
            id: 'conn_2',
            sourceBlockId: 'rag_1',
            targetBlockId: 'cot_1',
          ),
          const DspyBlockConnection(
            id: 'conn_3',
            sourceBlockId: 'cot_1',
            targetBlockId: 'output_1',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Code Generation Flow
  /// Input → CodeGen → Output
  ///
  /// Backend: POST /code/generate
  static DspyWorkflowTemplate codeGenerationFlow() {
    final now = DateTime.now();
    return DspyWorkflowTemplate(
      id: 'code_gen',
      name: 'Code Generation',
      description: 'Generate code with explanations, optionally execute',
      category: DspyWorkflowCategory.code,
      tags: ['code', 'generation', 'programming'],
      workflow: DspyWorkflow(
        id: 'code_gen_workflow',
        name: 'Code Generation',
        model: DspyModel.claude3Sonnet,
        blocks: [
          const DspyBlock(
            id: 'input_1',
            type: DspyBlockType.input,
            label: 'Code Task',
            position: BlockPosition(x: 100, y: 150),
            config: InputBlockConfig(
              variableName: 'task',
              description: 'Describe what code you need',
            ),
          ),
          const DspyBlock(
            id: 'codegen_1',
            type: DspyBlockType.codeGen,
            label: 'Generate Code',
            position: BlockPosition(x: 300, y: 150),
            config: CodeGenBlockConfig(
              language: 'python',
              executeCode: false,
            ),
          ),
          const DspyBlock(
            id: 'output_1',
            type: DspyBlockType.output,
            label: 'Code & Explanation',
            position: BlockPosition(x: 500, y: 150),
            config: OutputBlockConfig(
              variableName: 'code',
              includeReasoning: true,
            ),
          ),
        ],
        connections: [
          const DspyBlockConnection(
            id: 'conn_1',
            sourceBlockId: 'input_1',
            targetBlockId: 'codegen_1',
          ),
          const DspyBlockConnection(
            id: 'conn_2',
            sourceBlockId: 'codegen_1',
            targetBlockId: 'output_1',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Confidence Routing Flow
  /// Input → ChainOfThought → Decision → [High: Output, Low: TreeOfThought → Output]
  ///
  /// Backend: POST /reasoning, check confidence, route accordingly
  static DspyWorkflowTemplate confidenceRoutingFlow() {
    final now = DateTime.now();
    return DspyWorkflowTemplate(
      id: 'confidence_routing',
      name: 'Confidence-Based Routing',
      description: 'Route to deeper analysis when initial confidence is low',
      category: DspyWorkflowCategory.advanced,
      tags: ['advanced', 'routing', 'confidence', 'decision'],
      workflow: DspyWorkflow(
        id: 'confidence_routing_workflow',
        name: 'Confidence-Based Routing',
        model: DspyModel.claude3Sonnet,
        blocks: [
          const DspyBlock(
            id: 'input_1',
            type: DspyBlockType.input,
            label: 'Question',
            position: BlockPosition(x: 100, y: 200),
            config: InputBlockConfig(
              variableName: 'question',
              description: 'The question to answer',
            ),
          ),
          const DspyBlock(
            id: 'cot_1',
            type: DspyBlockType.chainOfThought,
            label: 'Initial Analysis',
            position: BlockPosition(x: 280, y: 200),
            config: ChainOfThoughtBlockConfig(),
          ),
          const DspyBlock(
            id: 'decision_1',
            type: DspyBlockType.decision,
            label: 'Confidence Check',
            position: BlockPosition(x: 460, y: 200),
            config: DecisionBlockConfig(
              confidenceThreshold: 0.7,
              highConfidenceOutput: 'direct_answer',
              lowConfidenceOutput: 'deeper_analysis',
            ),
          ),
          const DspyBlock(
            id: 'output_high',
            type: DspyBlockType.output,
            label: 'Quick Answer',
            position: BlockPosition(x: 680, y: 120),
            config: OutputBlockConfig(
              variableName: 'answer',
              includeReasoning: true,
            ),
          ),
          const DspyBlock(
            id: 'tot_1',
            type: DspyBlockType.treeOfThought,
            label: 'Deep Analysis',
            position: BlockPosition(x: 680, y: 280),
            config: TreeOfThoughtBlockConfig(
              numBranches: 3,
            ),
          ),
          const DspyBlock(
            id: 'output_low',
            type: DspyBlockType.output,
            label: 'Thorough Answer',
            position: BlockPosition(x: 900, y: 280),
            config: OutputBlockConfig(
              variableName: 'final_answer',
              includeReasoning: true,
            ),
          ),
        ],
        connections: [
          const DspyBlockConnection(
            id: 'conn_1',
            sourceBlockId: 'input_1',
            targetBlockId: 'cot_1',
          ),
          const DspyBlockConnection(
            id: 'conn_2',
            sourceBlockId: 'cot_1',
            targetBlockId: 'decision_1',
          ),
          const DspyBlockConnection(
            id: 'conn_3',
            sourceBlockId: 'decision_1',
            targetBlockId: 'output_high',
            sourcePin: 'high_confidence',
          ),
          const DspyBlockConnection(
            id: 'conn_4',
            sourceBlockId: 'decision_1',
            targetBlockId: 'tot_1',
            sourcePin: 'low_confidence',
          ),
          const DspyBlockConnection(
            id: 'conn_5',
            sourceBlockId: 'tot_1',
            targetBlockId: 'output_low',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

/// Template metadata
class DspyWorkflowTemplate {
  final String id;
  final String name;
  final String description;
  final DspyWorkflowCategory category;
  final List<String> tags;
  final DspyWorkflow workflow;

  const DspyWorkflowTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.tags,
    required this.workflow,
  });
}

/// Workflow categories
enum DspyWorkflowCategory {
  reasoning('Reasoning', 'Pure reasoning patterns'),
  agent('Agent', 'Tool-using agents'),
  rag('RAG', 'Document retrieval and Q&A'),
  code('Code', 'Code generation and execution'),
  advanced('Advanced', 'Complex multi-step workflows');

  const DspyWorkflowCategory(this.displayName, this.description);

  final String displayName;
  final String description;
}
