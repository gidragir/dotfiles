---
name: subagent-driven-development
description: >-
  Executes implementation plans using isolated subagents for each step with two-stage review.
  Activate when executing multi-step tasks, refactorings, or complex features requiring context isolation.
---

# Subagent-Driven Development (Superpowers Workflow)

This workflow executes multi-step plans by delegating each task to isolated subagents, protecting the coordinator's context window and ensuring high-rigor quality control.

## Process Flow

```
[Approved Plan] 
       │
       ▼
  For each task step:
       ├── 1. Gather Context (Optional)  ──► researcher (Flash)
       ├── 2. System Pre-Audit (If OS)   ──► system-architect (Pro)
       ├── 3. Discrete Implementation    ──► implementer (Inherit)
       ├── 4. Spec & Code Review         ──► code-reviewer (Pro)
       │         └── If changes requested: loop back to implementer (max 3 cycles)
       ├── 5. Automated Validation       ──► tester-validator (Flash)
       └── 6. Mark Complete in Plan
```

## Step-by-Step Instructions

### Step 1: Initialize Task Step
- Extract the single current step from the active plan (`implementation_plan.md`).
- Ensure prerequisites and dependencies from previous steps are met.

### Step 2: Context Gathering (Optional / Fast)
- If the step requires locating symbols, usages, or configs across directories, invoke `researcher` (model: `flash`).
- **Input**: Target concept, suspected directories, and question.
- **Output**: Compact summary with exact file and line references.

### Step 3: System Pre-Audit (Conditional)
- If the step touches block devices, `/etc/fstab`, systemd system units, KVM/QEMU, or Niri core, invoke `system-architect` (model: `pro`).
- **Input**: Proposed system modification and targeted block devices or services.
- **Condition**: Proceed to implementation only if Risk Score is `LOW` or mitigations are confirmed.

### Step 4: Discrete Implementation
- Invoke `implementer` with the specific task scope and gathered context.
- **Input**: Exact file paths, target behavior, and architectural rules.
- **Output**: Confirmation of changes and modified file list.

### Step 5: Two-Stage Review & Validation
1. **Spec & Architecture Review**:
   - Invoke `code-reviewer` (model: `pro`) on the changes.
   - If findings are marked `CRITICAL` or `WARNING`, re-dispatch `implementer` to address fixes.
   - Cap iterations at **3 review cycles** to avoid infinite review loops.
2. **Automated Validation**:
   - Invoke `tester-validator` (model: `flash`) to run linters, format checks, or test suites.

### Step 6: Step Completion & Progress Update
- Update `implementation_plan.md` checking off the completed task.
- Proceed to the next step.
