// Reads an ECS task definition (aws ecs describe-task-definition --query taskDefinition) on stdin and prints a
// register-task-definition input with every ai-agent-desk image retagged: node ecs-new-taskdef.mjs <tag>
const tag = process.argv[2];
if (!tag) throw new Error("usage: ecs-new-taskdef.mjs <tag>");
let input = "";
for await (const chunk of process.stdin) input += chunk;
const td = JSON.parse(input);

const keep = ["family", "taskRoleArn", "executionRoleArn", "networkMode", "containerDefinitions", "volumes", "requiresCompatibilities", "cpu", "memory", "runtimePlatform"];
const out = Object.fromEntries(keep.filter((k) => td[k] !== undefined).map((k) => [k, td[k]]));
out.containerDefinitions = td.containerDefinitions.map((c) => ({
  ...c,
  image: /\/ai-agent-desk\//.test(c.image) ? c.image.replace(/:[^:/]+$/, `:${tag}`) : c.image,
}));
process.stdout.write(JSON.stringify(out));
