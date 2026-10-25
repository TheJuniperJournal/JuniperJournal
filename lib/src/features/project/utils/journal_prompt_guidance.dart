/// Creator guidance only: labels, storage keys and completion rules stay stable.
const journalPromptGuidance = <String, String>{
  'Discovery Title':
      'Give this entry a short title that captures what you noticed or want to understand.',
  'What was observed?':
      'Describe what you noticed, including a specific example, change, or experience. What details would help someone who was not there understand it?',
  'Location':
      'Where did this happen? Include the place or setting if it helps explain the situation.',
  'What is already known?':
      'What do you already know from experience, earlier work, or other sources? Separate what is known from what you still need to check.',
  'Root Cause':
      'Name one possible underlying cause. Treat it as an explanation to investigate, rather than a confirmed conclusion.',
  'Short Description':
      'Describe how this cause could contribute to what you observed.',
  'Why do you think this occurs?':
      'What observation, experience, or source supports this explanation? Note any assumptions or other possible explanations.',
  'Why was this pattern selected?':
      'Explain how this kind of change could address the situation. What would be different, and who or what could benefit?',
  'Challenge Title': 'Give the challenge a short, recognizable name.',
  'Challenge':
      'Describe the situation you want to improve, why it matters, and the people, places, or systems involved.',
  'Description':
      'Describe the idea clearly enough for someone else to picture it. What would change?',
  'How would it work?':
      'Explain the steps or mechanism behind the idea. Why might it address the challenge?',
  'Strengths':
      'What makes this idea useful or practical in this context? Consider its benefits, resources, and accessibility.',
  'Challenges':
      'What could make this idea difficult to carry out? Note constraints, tradeoffs, or questions to investigate.',
  'Name': 'Give this part of the project a name others will recognize.',
  'Purpose of the Component':
      'What role does this part play in the wider project, activity, or system?',
  'Key Features':
      'List the characteristics that matter for its purpose, use, or performance.',
  'Build Title': 'Name the work or change documented in this entry.',
  'Objective':
      'What are you trying to create, change, learn, or evaluate? Explain what a useful outcome would look like.',
  'Build Process':
      'Describe what you made, assembled, or changed and the order you worked in. Explain important choices and adjustments so someone else could follow your approach.',
  'Design Notes':
      'Record decisions, constraints, unexpected changes, or details worth remembering for the next iteration.',
  'Test Title': 'Give this test or investigation a short, specific name.',
  'Method':
      'Explain what you did, what you observed or measured, and the conditions you kept consistent. Include enough detail to repeat or compare the test.',
  'Expected Outcome':
      'Before considering the results, describe what you expected to happen and what would indicate success or useful progress.',
  'Feedback & Notes':
      'What actually happened? Include specific observations or results, explain the rating you chose, and note limitations or feedback.',
  'Technical Analysis Title':
      'Name the question, comparison, or calculation explored here.',
  'Baseline Description':
      'Describe the starting conditions or reference case. Include relevant quantities, units, timeframe, and assumptions.',
  'Proposed Description':
      'Describe the alternative conditions or approach. Use comparable boundaries, units, and timeframes where possible.',
  'Field Notes':
      'Explain your calculations or interpretation, including units, sources, assumptions, and uncertainty. What can the evidence support, and what still needs checking?',
  'Implementation Title':
      'Name the activity, change, or solution put into practice.',
  'Summary':
      'Describe what was put into practice, how it was carried out, and who or what was involved. Include relevant details and evidence of what happened.',
  'What worked well?':
      'Describe a specific success and what helped it happen. What would you keep or repeat?',
  "What didn't work well?":
      'Describe what fell short, changed unexpectedly, or remained difficult. What might explain it?',
  'Key Takeaways':
      'What have you learned from putting this into practice? Explain how the experience changed or strengthened your understanding.',
  'What would you change?':
      'What would you adapt next time, and why? Connect the change to what you observed or learned.',
  'What did you learn today?':
      'Explain one insight from this entry and the observation, evidence, or experience behind it. How has your understanding changed?',
  'What challenges or questions came up?':
      'What remains uncertain, difficult, or unresolved? Explain why it matters and what could help you investigate it.',
  'What are next steps?':
      'Describe a specific next action, why it follows from this entry, and what you will look for to judge progress.',
  'Open Notes':
      'Add anything else worth keeping: an unexpected observation, a connection, a question, or a note for a collaborator.',
};

const journalPromptAliases = <String, String>{
  'What Challenge are we trying to solve?': 'Challenge',
  'Describe the Idea': 'Description',
  'What are the strengths of this idea?': 'Strengths',
  'What are the challenges of this idea?': 'Challenges',
  'Title': 'Build Title',
};

String? guidanceForJournalPrompt(String label) {
  final clean = label.replaceAll(' (Optional)', '');
  return journalPromptGuidance[journalPromptAliases[clean] ?? clean];
}
