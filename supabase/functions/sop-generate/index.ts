import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type DegreeLevel = "Undergraduate" | "Master's";
type SOPProjectMode = "Master SOP" | "Program-Specific SOP" | "Scholarship Essay";

type StudentProfile = {
  fullName: string;
  subjectArea: string;
  targetIntake: string;
  degreeLevel: DegreeLevel;
  currentCountry: string;
  nationality: string;
  undergraduateInstitution?: string;
  workExperienceYears?: number;
};

type Program = {
  name: string;
  universityName: string;
  subjectArea: string;
  degreeLevel: DegreeLevel;
  country?: string;
};

type Scholarship = {
  name: string;
  sponsor: string;
  summary: string;
};

type SOPQuestionAnswer = {
  id: string;
  question: string;
  answer: string;
};

type RequestPayload = {
  profile: StudentProfile;
  program?: Program | null;
  scholarship?: Scholarship | null;
  mode: SOPProjectMode;
  answers: SOPQuestionAnswer[];
};

const jsonHeaders = { "Content-Type": "application/json" };

serve(async (request) => {
  if (request.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed." }), {
      status: 405,
      headers: jsonHeaders,
    });
  }

  let payload: RequestPayload;
  try {
    payload = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON payload." }), {
      status: 400,
      headers: jsonHeaders,
    });
  }

  const evidence = payload.answers
    .map((item) => item.answer.trim())
    .filter(Boolean)
    .slice(0, 6);

  const focusTarget = payload.program
    ? `${payload.program.name} at ${payload.program.universityName}`
    : payload.scholarship
      ? `${payload.scholarship.name} from ${payload.scholarship.sponsor}`
      : "international study plans";

  const outline = [
    `Opening motivation for ${focusTarget}`,
    `Academic preparation in ${payload.profile.subjectArea}`,
    "Evidence-backed achievements and projects",
    "Career direction and country fit",
    "Why this opportunity is realistic now",
  ];

  const draft = [
    `${payload.profile.fullName || "The applicant"} is preparing a ${payload.mode.toLowerCase()} focused on ${focusTarget}.`,
    `The core academic direction is ${payload.profile.subjectArea}, with a target intake of ${payload.profile.targetIntake}.`,
    evidence.length > 0
      ? `The strongest available evidence includes ${evidence.join("; ")}.`
      : "The current draft still needs stronger concrete evidence from academics, projects, and outcomes.",
    payload.program
      ? `This draft should stay tailored to ${payload.program.universityName} and explain why the program matches the student's preparation and constraints.`
      : payload.scholarship
        ? `This draft should explain why the applicant is a credible funding candidate and how the scholarship changes the feasibility of the study plan.`
        : "This draft should connect motivation, preparation, and realistic next steps without drifting into generic claims.",
  ].join("\n\n");

  const critiqueFlags = [];
  if (evidence.length < 3) {
    critiqueFlags.push({
      id: "flag_evidence",
      type: "Needs Stronger Evidence",
      message: "Add more concrete coursework, projects, internships, or measurable outcomes.",
    });
  }
  if (draft.length > 2200) {
    critiqueFlags.push({
      id: "flag_length",
      type: "Length Warning",
      message: "The generated draft is running long for a first-pass SOP.",
    });
  }
  if (!draft.toLowerCase().includes("career")) {
    critiqueFlags.push({
      id: "flag_goal",
      type: "Goal Clarity",
      message: "Clarify the post-study career direction and how this application supports it.",
    });
  }

  return new Response(
    JSON.stringify({
      outline,
      draft,
      critiqueFlags,
    }),
    { status: 200, headers: jsonHeaders },
  );
});
