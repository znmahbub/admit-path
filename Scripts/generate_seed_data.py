#!/usr/bin/env python3

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SEED_DIR = ROOT / "AdmitPath" / "SeedData"


def slug(text: str) -> str:
    return (
        text.lower()
        .replace("&", "and")
        .replace("'", "")
        .replace("-", "_")
        .replace(" ", "_")
    )


country_specs = [
    {
        "country": "Canada",
        "region": "North America",
        "living": 15000,
        "undergrad_portal": "University Portal",
        "masters_portal": "University Portal",
        "intakes": [
            ("Fall 2027", "2027-02-01", "2027-01-10", "2027-04-15", "2027-03-01", "2027-05-01"),
            ("Winter 2028", "2027-08-01", "2027-07-10", "2027-09-10", "2027-09-01", "2027-10-01"),
        ],
        "universities": [
            ("uni_toronto_metropolitan", "Toronto Metropolitan University", "Toronto", "Top 200"),
            ("uni_ottawa", "University of Ottawa", "Ottawa", "Top 200"),
        ],
    },
    {
        "country": "United Kingdom",
        "region": "Europe",
        "living": 16000,
        "undergrad_portal": "UCAS",
        "masters_portal": "Graduate Admissions Portal",
        "intakes": [
            ("September 2027", "2027-03-15", "2027-02-20", "2027-05-05", "2027-04-05", "2027-05-20"),
            ("January 2028", "2027-09-15", "2027-08-20", "2027-10-20", "2027-10-01", "2027-11-05"),
        ],
        "universities": [
            ("uni_leeds", "University of Leeds", "Leeds", "Top 100"),
            ("uni_birmingham", "University of Birmingham", "Birmingham", "Top 100"),
        ],
    },
    {
        "country": "United States",
        "region": "North America",
        "living": 18000,
        "undergrad_portal": "Common App",
        "masters_portal": "Graduate Portal",
        "intakes": [
            ("Fall 2027", "2026-12-15", "2026-12-01", "2027-04-20", "2027-02-15", "2027-05-01"),
            ("Spring 2028", "2027-08-15", "2027-07-25", "2027-11-15", "2027-09-20", "2027-12-05"),
        ],
        "universities": [
            ("uni_arizona_state", "Arizona State University", "Tempe", "Top 200"),
            ("uni_northeastern", "Northeastern University", "Boston", "Top 100"),
        ],
    },
    {
        "country": "Australia",
        "region": "Oceania",
        "living": 17000,
        "undergrad_portal": "Direct Apply",
        "masters_portal": "Direct Apply",
        "intakes": [
            ("Semester 1 2028", "2027-10-15", "2027-09-20", "2027-12-10", "2027-11-10", "2028-01-10"),
            ("Semester 2 2028", "2028-03-15", "2028-02-20", "2028-05-10", "2028-04-05", "2028-06-01"),
        ],
        "universities": [
            ("uni_monash", "Monash University", "Melbourne", "Top 100"),
            ("uni_deakin", "Deakin University", "Melbourne", "Top 250"),
        ],
    },
    {
        "country": "Malaysia",
        "region": "Asia",
        "living": 9000,
        "undergrad_portal": "University Portal",
        "masters_portal": "University Portal",
        "intakes": [
            ("October 2027", "2027-06-15", "2027-05-25", "2027-08-10", "2027-07-10", "2027-09-01"),
            ("February 2028", "2027-10-30", "2027-10-01", "2027-12-15", "2027-11-15", "2028-01-05"),
        ],
        "universities": [
            ("uni_malaya", "University of Malaya", "Kuala Lumpur", "Top 150"),
            ("uni_taylors", "Taylor's University", "Subang Jaya", "Top 300"),
        ],
    },
    {
        "country": "Hong Kong",
        "region": "Asia",
        "living": 15000,
        "undergrad_portal": "University Portal",
        "masters_portal": "University Portal",
        "intakes": [
            ("Fall 2027", "2027-01-10", "2026-12-20", "2027-04-15", "2027-02-15", "2027-05-01"),
            ("Spring 2028", "2027-09-01", "2027-08-10", "2027-11-10", "2027-10-01", "2027-12-01"),
        ],
        "universities": [
            ("uni_cityu_hk", "City University of Hong Kong", "Hong Kong", "Top 100"),
            ("uni_hkbu", "Hong Kong Baptist University", "Hong Kong", "Top 250"),
        ],
    },
    {
        "country": "Germany",
        "region": "Europe",
        "living": 12000,
        "undergrad_portal": "Uni-Assist",
        "masters_portal": "Uni-Assist",
        "intakes": [
            ("Winter 2027", "2027-05-31", "2027-05-10", "2027-08-15", "2027-06-20", "2027-09-01"),
            ("Summer 2028", "2027-11-30", "2027-11-10", "2028-02-01", "2027-12-20", "2028-02-20"),
        ],
        "universities": [
            ("uni_mannheim", "University of Mannheim", "Mannheim", "Top 150"),
            ("uni_tu_berlin", "Technical University of Berlin", "Berlin", "Top 150"),
        ],
    },
    {
        "country": "Netherlands",
        "region": "Europe",
        "living": 14000,
        "undergrad_portal": "Studielink",
        "masters_portal": "Studielink",
        "intakes": [
            ("September 2027", "2027-04-01", "2027-03-10", "2027-06-15", "2027-05-01", "2027-07-01"),
            ("February 2028", "2027-10-15", "2027-09-20", "2027-12-01", "2027-11-01", "2028-01-05"),
        ],
        "universities": [
            ("uni_groningen", "University of Groningen", "Groningen", "Top 150"),
            ("uni_erasmus", "Erasmus University Rotterdam", "Rotterdam", "Top 100"),
        ],
    },
    {
        "country": "Ireland",
        "region": "Europe",
        "living": 15500,
        "undergrad_portal": "CAO",
        "masters_portal": "University Portal",
        "intakes": [
            ("September 2027", "2027-03-01", "2027-02-10", "2027-05-20", "2027-04-10", "2027-06-01"),
            ("January 2028", "2027-09-30", "2027-09-05", "2027-11-20", "2027-10-15", "2027-12-05"),
        ],
        "universities": [
            ("uni_ucd", "University College Dublin", "Dublin", "Top 150"),
            ("uni_galway", "University of Galway", "Galway", "Top 250"),
        ],
    },
]


program_templates = [
    {
        "name": "MSc Business Analytics",
        "subject": "Business Analytics",
        "degree": "Master's",
        "duration": 12,
        "tuition": 27000,
        "fee": 95,
        "min_gpa": 3.1,
        "min_secondary": None,
        "ielts": 6.5,
        "lor": 2,
        "cv": True,
        "sop": True,
        "financial": True,
        "portfolio": False,
    },
    {
        "name": "MSc Data Science",
        "subject": "Data Science",
        "degree": "Master's",
        "duration": 12,
        "tuition": 28000,
        "fee": 100,
        "min_gpa": 3.2,
        "min_secondary": None,
        "ielts": 6.5,
        "lor": 2,
        "cv": True,
        "sop": True,
        "financial": True,
        "portfolio": False,
    },
    {
        "name": "MSc Finance",
        "subject": "Finance",
        "degree": "Master's",
        "duration": 12,
        "tuition": 29000,
        "fee": 95,
        "min_gpa": 3.2,
        "min_secondary": None,
        "ielts": 6.5,
        "lor": 2,
        "cv": True,
        "sop": True,
        "financial": True,
        "portfolio": False,
    },
    {
        "name": "MPP Public Policy",
        "subject": "Public Policy",
        "degree": "Master's",
        "duration": 12,
        "tuition": 25500,
        "fee": 85,
        "min_gpa": 3.0,
        "min_secondary": None,
        "ielts": 6.5,
        "lor": 2,
        "cv": True,
        "sop": True,
        "financial": True,
        "portfolio": False,
    },
    {
        "name": "BSc Computer Science",
        "subject": "Computer Science",
        "degree": "Undergraduate",
        "duration": 48,
        "tuition": 22000,
        "fee": 70,
        "min_gpa": 0,
        "min_secondary": 88.0,
        "ielts": 6.0,
        "lor": 1,
        "cv": False,
        "sop": True,
        "financial": True,
        "portfolio": False,
    },
    {
        "name": "BSc Business Analytics",
        "subject": "Business Analytics",
        "degree": "Undergraduate",
        "duration": 48,
        "tuition": 21000,
        "fee": 65,
        "min_gpa": 0,
        "min_secondary": 84.0,
        "ielts": 6.0,
        "lor": 1,
        "cv": False,
        "sop": True,
        "financial": True,
        "portfolio": False,
    },
    {
        "name": "BA Economics",
        "subject": "Economics",
        "degree": "Undergraduate",
        "duration": 36,
        "tuition": 20500,
        "fee": 60,
        "min_gpa": 0,
        "min_secondary": 82.0,
        "ielts": 6.0,
        "lor": 1,
        "cv": False,
        "sop": True,
        "financial": True,
        "portfolio": False,
    },
    {
        "name": "BEng Engineering",
        "subject": "Engineering",
        "degree": "Undergraduate",
        "duration": 48,
        "tuition": 23000,
        "fee": 75,
        "min_gpa": 0,
        "min_secondary": 86.0,
        "ielts": 6.0,
        "lor": 1,
        "cv": False,
        "sop": True,
        "financial": True,
        "portfolio": True,
    },
]


universities = []
programs = []
requirements = []
deadlines = []


for country_index, spec in enumerate(country_specs):
    for uni_index, (uni_id, name, city, ranking_bucket) in enumerate(spec["universities"]):
        universities.append(
            {
                "id": uni_id,
                "name": name,
                "country": spec["country"],
                "city": city,
                "websiteURL": f"https://example.org/{uni_id}",
                "rankingBucket": ranking_bucket,
                "type": "Public",
                "region": spec["region"],
                "featuredForBangladesh": True,
            }
        )

        template_start = (country_index * 2 + uni_index) % len(program_templates)
        selected_templates = [
            program_templates[template_start],
            program_templates[(template_start + 4) % len(program_templates)],
        ]

        for template in selected_templates:
            degree_slug = "masters" if template["degree"] == "Master's" else "undergrad"
            program_id = f"{uni_id}_{slug(template['subject'])}_{degree_slug}"
            portal = spec["masters_portal"] if template["degree"] == "Master's" else spec["undergrad_portal"]
            tuition = template["tuition"] + (country_index * 700) + (uni_index * 350)
            living = spec["living"] + (2000 if template["degree"] == "Undergraduate" else 0)

            programs.append(
                {
                    "id": program_id,
                    "universityID": uni_id,
                    "universityName": name,
                    "name": template["name"],
                    "degreeLevel": template["degree"],
                    "subjectArea": template["subject"],
                    "durationMonths": template["duration"],
                    "tuitionUSD": tuition,
                    "applicationFeeUSD": template["fee"],
                    "officialURL": f"https://example.org/{uni_id}/{program_id}",
                    "summary": f"A structured {template['degree'].lower()} pathway in {template['subject'].lower()} with practical coursework and international student support.",
                    "intakeTerms": [intake[0] for intake in spec["intakes"]],
                    "scholarshipAvailable": template["subject"] in {"Business Analytics", "Data Science", "Finance", "Public Policy", "Engineering"},
                    "applicationPortal": portal,
                    "studyMode": "Full Time",
                    "estimatedLivingCostUSD": living,
                    "totalCostOfAttendanceUSD": tuition + living,
                    "dataFreshness": "Updated Mar 2026",
                    "lastUpdatedAt": "2026-03-15T10:00:00Z",
                    "bangladeshFitNote": "Strong option for Bangladeshi applicants who need clear budgeting and deadline visibility.",
                }
            )

            requirements.append(
                {
                    "id": f"req_{program_id}",
                    "programID": program_id,
                    "minGPAValue": template["min_gpa"],
                    "minGPAScale": 4.0,
                    "minSecondaryPercent": template["min_secondary"],
                    "ieltsMin": template["ielts"],
                    "toeflMin": 88 if template["ielts"] >= 6.5 else 80,
                    "duolingoMin": 120 if template["ielts"] >= 6.5 else 110,
                    "satMin": 1350 if spec["country"] == "United States" and template["degree"] == "Undergraduate" else None,
                    "greRequired": False,
                    "gmatRequired": False,
                    "sopRequired": template["sop"],
                    "cvRequired": template["cv"],
                    "lorCount": template["lor"],
                    "transcriptRequired": True,
                    "passportRequired": True,
                    "financialProofRequired": template["financial"],
                    "portfolioRequired": template["portfolio"],
                    "notes": "Requirements are demo-quality and should be verified against the official source before production use.",
                }
            )

            for intake_name, app_deadline, scholarship_deadline, deposit_deadline, interview_start, visa_start in spec["intakes"]:
                deadlines.append(
                    {
                        "id": f"dl_{program_id}_{slug(intake_name)}",
                        "programID": program_id,
                        "intakeTerm": intake_name,
                        "applicationDeadline": app_deadline,
                        "scholarshipDeadline": scholarship_deadline,
                        "depositDeadline": deposit_deadline,
                        "interviewWindowStart": interview_start,
                        "visaPrepStart": visa_start,
                        "decisionExpected": deposit_deadline,
                        "notes": "Use this as a planning anchor, then verify on the official portal.",
                    }
                )


scholarships = []
for spec in country_specs:
    country_slug = slug(spec["country"])
    scholarships.extend(
        [
            {
                "id": f"sch_{country_slug}_merit",
                "name": f"{spec['country']} Merit Pathway Award",
                "sponsor": f"{spec['country']} Graduate Access Network",
                "destinationCountries": [spec["country"]],
                "eligibleNationalities": ["Bangladesh", "India", "Pakistan", "Nepal", "Sri Lanka"],
                "eligibleSubjects": ["Business Analytics", "Data Science", "Finance", "Engineering"],
                "eligibleDegreeLevels": ["Master's", "Undergraduate"],
                "minGPAValue": 3.1,
                "minSecondaryPercent": 85.0,
                "coverageType": "Partial Tuition",
                "maxAmountUSD": 10000,
                "officialURL": f"https://example.org/scholarships/{country_slug}_merit",
                "summary": f"Merit support for South Asian students targeting {spec['country']}.",
                "deadline": spec["intakes"][0][2],
                "needBased": False,
                "meritBased": True,
                "lastUpdatedAt": "2026-03-15T10:00:00Z",
                "essayPromptHint": "Explain how the degree changes your options relative to your current budget.",
            },
            {
                "id": f"sch_{country_slug}_need",
                "name": f"{spec['country']} Opportunity Scholarship",
                "sponsor": f"{spec['country']} Student Opportunity Fund",
                "destinationCountries": [spec["country"]],
                "eligibleNationalities": ["Bangladesh", "India", "Pakistan", "Nepal", "Sri Lanka"],
                "eligibleSubjects": ["Business Analytics", "Business", "Economics", "Public Policy", "Computer Science"],
                "eligibleDegreeLevels": ["Master's", "Undergraduate"],
                "minGPAValue": 3.0,
                "minSecondaryPercent": 82.0,
                "coverageType": "Tuition and Stipend",
                "maxAmountUSD": 22000,
                "officialURL": f"https://example.org/scholarships/{country_slug}_need",
                "summary": f"Need-sensitive funding for applicants who would otherwise face a binding affordability gap in {spec['country']}.",
                "deadline": spec["intakes"][0][2],
                "needBased": True,
                "meritBased": False,
                "lastUpdatedAt": "2026-03-15T10:00:00Z",
                "essayPromptHint": "Explain why funding changes feasibility and how you will use the opportunity responsibly.",
            },
        ]
    )


sample_profile = {
    "id": "student_demo",
    "fullName": "Nadia Rahman",
    "nationality": "Bangladesh",
    "currentCountry": "Bangladesh",
    "homeCity": "Dhaka",
    "targetIntake": "Fall 2027",
    "degreeLevel": "Master's",
    "subjectArea": "Business Analytics",
    "secondaryCurriculum": "Bangladesh HSC",
    "secondaryResultPercent": 91.2,
    "undergraduateInstitution": "North South University",
    "gpaValue": 3.62,
    "gpaScale": 4.0,
    "englishTestType": "IELTS",
    "englishTestScore": 7.5,
    "satScore": None,
    "greScore": None,
    "gmatScore": None,
    "workExperienceYears": 2,
    "scholarshipNeeded": True,
    "annualBudgetUSD": 34000,
    "tuitionBudgetUSD": 24000,
    "annualBudgetBDT": 4200000,
    "tuitionBudgetBDT": 2900000,
    "preferredCountries": ["Canada", "United Kingdom", "Australia"],
    "targetCities": ["Toronto", "Leeds", "Melbourne"],
    "targetUniversityNames": ["Toronto Metropolitan University", "University of Leeds"],
    "documentStatus": {
        "sopDraftReady": False,
        "cvReady": False,
        "lorsReady": False,
        "transcriptReady": True,
        "englishScoreReady": True,
        "passportReady": False,
        "financialsReady": False,
        "scholarshipEssayReady": False,
        "portfolioReady": False,
    },
    "onboardingComplete": True,
}


masters_programs = [program for program in programs if program["degreeLevel"] == "Master's"]
university_country = {university["id"]: university["country"] for university in universities}
sample_program_a = masters_programs[0]
sample_program_b = masters_programs[3]

sample_applications = [
    {
        "id": "app_tmu_analytics",
        "programID": sample_program_a["id"],
        "universityName": sample_program_a["universityName"],
        "programName": sample_program_a["name"],
        "country": "Canada",
        "status": "Preparing Docs",
        "completionPercent": 45,
        "notes": "Good affordability trade-off if a partial scholarship lands. Need sharper country rationale in the SOP.",
        "linkedScholarshipIDs": [scholarships[0]["id"]],
        "createdAt": "2026-11-15T09:00:00Z",
        "targetDeadline": "2027-02-01",
    },
    {
        "id": "app_uk_policy",
        "programID": sample_program_b["id"],
        "universityName": sample_program_b["universityName"],
        "programName": sample_program_b["name"],
        "country": university_country[sample_program_b["universityID"]],
        "status": "Researching",
        "completionPercent": 20,
        "notes": "Interesting fit, but cost pressure is higher. Need to compare against Canada before committing.",
        "linkedScholarshipIDs": [scholarships[2]["id"]],
        "createdAt": "2026-11-20T12:00:00Z",
        "targetDeadline": "2027-03-15",
    },
]

sample_tasks = [
    {"id": "task_1", "applicationID": "app_tmu_analytics", "title": "Review official requirements", "dueDate": "2026-12-10", "taskType": "Requirements Review", "isCompleted": True, "isAutoGenerated": True, "notes": ""},
    {"id": "task_2", "applicationID": "app_tmu_analytics", "title": "Request transcript", "dueDate": "2027-01-05", "taskType": "Transcript", "isCompleted": True, "isAutoGenerated": True, "notes": ""},
    {"id": "task_3", "applicationID": "app_tmu_analytics", "title": "Prepare CV", "dueDate": "2027-01-10", "taskType": "CV", "isCompleted": False, "isAutoGenerated": True, "notes": ""},
    {"id": "task_4", "applicationID": "app_tmu_analytics", "title": "Draft SOP", "dueDate": "2027-01-15", "taskType": "SOP", "isCompleted": False, "isAutoGenerated": True, "notes": ""},
    {"id": "task_5", "applicationID": "app_tmu_analytics", "title": "Draft scholarship essay base", "dueDate": "2027-01-12", "taskType": "Scholarship Essay", "isCompleted": False, "isAutoGenerated": True, "notes": ""},
    {"id": "task_6", "applicationID": "app_tmu_analytics", "title": "Prepare financial proof", "dueDate": "2027-01-18", "taskType": "Financial Proof", "isCompleted": False, "isAutoGenerated": True, "notes": ""},
    {"id": "task_7", "applicationID": "app_uk_policy", "title": "Review official requirements", "dueDate": "2026-12-15", "taskType": "Requirements Review", "isCompleted": False, "isAutoGenerated": True, "notes": ""},
    {"id": "task_8", "applicationID": "app_uk_policy", "title": "Draft SOP", "dueDate": "2027-01-25", "taskType": "SOP", "isCompleted": False, "isAutoGenerated": True, "notes": ""},
    {"id": "task_9", "applicationID": "app_uk_policy", "title": "Upload passport copy", "dueDate": "2027-02-01", "taskType": "Passport", "isCompleted": False, "isAutoGenerated": True, "notes": ""},
    {"id": "task_10", "applicationID": "app_uk_policy", "title": "Submit application", "dueDate": "2027-03-15", "taskType": "Submit", "isCompleted": False, "isAutoGenerated": True, "notes": ""},
]


peer_profiles = [
    {
        "id": "peer_sadia",
        "displayName": "Sadia H.",
        "nationality": "Bangladesh",
        "currentCountry": "Canada",
        "role": "Current Student",
        "verificationStatus": "Verified Student",
        "currentUniversity": "Toronto Metropolitan University",
        "currentProgram": "MSc Business Analytics",
        "bio": "Came from Dhaka, handled the whole process without a consultant, now sharing what actually mattered.",
        "subjectAreas": ["Business Analytics"],
        "targetCountries": ["Canada"],
        "reputationScore": 92,
        "outcomes": [
            {
                "id": "outcome_sadia_1",
                "universityName": "Toronto Metropolitan University",
                "programName": "MSc Business Analytics",
                "country": "Canada",
                "degreeLevel": "Master's",
                "intake": "Fall 2027",
                "result": "Enrolled",
            }
        ],
    },
    {
        "id": "peer_faisal",
        "displayName": "Faisal R.",
        "nationality": "Bangladesh",
        "currentCountry": "United Kingdom",
        "role": "Admit",
        "verificationStatus": "Verified Admit",
        "currentUniversity": "University of Leeds",
        "currentProgram": "MSc Data Science",
        "bio": "Focused on scholarships and a realistic shortlist instead of prestige chasing.",
        "subjectAreas": ["Data Science"],
        "targetCountries": ["United Kingdom"],
        "reputationScore": 88,
        "outcomes": [
            {
                "id": "outcome_faisal_1",
                "universityName": "University of Leeds",
                "programName": "MSc Data Science",
                "country": "United Kingdom",
                "degreeLevel": "Master's",
                "intake": "September 2027",
                "result": "Admit",
            }
        ],
    },
    {
        "id": "peer_nabila",
        "displayName": "Nabila K.",
        "nationality": "Bangladesh",
        "currentCountry": "Australia",
        "role": "Current Student",
        "verificationStatus": "Verified Student",
        "currentUniversity": "Monash University",
        "currentProgram": "BSc Computer Science",
        "bio": "Undergrad applicant who learned quickly which portals and deadlines actually mattered.",
        "subjectAreas": ["Computer Science"],
        "targetCountries": ["Australia"],
        "reputationScore": 85,
        "outcomes": [
            {
                "id": "outcome_nabila_1",
                "universityName": "Monash University",
                "programName": "BSc Computer Science",
                "country": "Australia",
                "degreeLevel": "Undergraduate",
                "intake": "Semester 1 2028",
                "result": "Enrolled",
            }
        ],
    },
    {
        "id": "peer_rafi",
        "displayName": "Rafi A.",
        "nationality": "Bangladesh",
        "currentCountry": "United States",
        "role": "Alumni",
        "verificationStatus": "Verified Alumni",
        "currentUniversity": "Arizona State University",
        "currentProgram": "MSc Finance",
        "bio": "Now working in data-heavy finance. Shares direct advice on affordability and visa timing.",
        "subjectAreas": ["Finance"],
        "targetCountries": ["United States"],
        "reputationScore": 94,
        "outcomes": [
            {
                "id": "outcome_rafi_1",
                "universityName": "Arizona State University",
                "programName": "MSc Finance",
                "country": "United States",
                "degreeLevel": "Master's",
                "intake": "Fall 2027",
                "result": "Graduated",
            }
        ],
    },
    {
        "id": "peer_mahi",
        "displayName": "Mahi S.",
        "nationality": "Bangladesh",
        "currentCountry": "Netherlands",
        "role": "Applicant",
        "verificationStatus": "Unverified",
        "currentUniversity": "University of Groningen",
        "currentProgram": "BA Economics",
        "bio": "Still in the process and asking detailed questions about budgets and portals.",
        "subjectAreas": ["Economics"],
        "targetCountries": ["Netherlands"],
        "reputationScore": 52,
        "outcomes": [],
    },
    {
        "id": "peer_tahsin",
        "displayName": "Tahsin M.",
        "nationality": "Bangladesh",
        "currentCountry": "Hong Kong",
        "role": "Current Student",
        "verificationStatus": "Verified Student",
        "currentUniversity": "City University of Hong Kong",
        "currentProgram": "BSc Business Analytics",
        "bio": "Keeps detailed notes on document sequencing and scholarship essays.",
        "subjectAreas": ["Business Analytics"],
        "targetCountries": ["Hong Kong"],
        "reputationScore": 79,
        "outcomes": [
            {
                "id": "outcome_tahsin_1",
                "universityName": "City University of Hong Kong",
                "programName": "BSc Business Analytics",
                "country": "Hong Kong",
                "degreeLevel": "Undergraduate",
                "intake": "Fall 2027",
                "result": "Enrolled",
            }
        ],
    },
]


peer_posts = [
    {
        "id": "post_1",
        "authorID": "peer_sadia",
        "title": "What changed my shortlist for Canada",
        "body": "I stopped thinking in terms of rankings only and started comparing total annual cost, scholarship timing, and whether the curriculum actually matched my prior coursework.",
        "kind": "Admit Story",
        "country": "Canada",
        "subjectArea": "Business Analytics",
        "degreeLevel": "Master's",
        "programID": sample_program_a["id"],
        "scholarshipID": scholarships[0]["id"],
        "tags": ["budget", "shortlist", "bangladesh"],
        "moderationStatus": "Clear",
        "createdAt": "2026-03-20T10:00:00Z",
        "upvoteCount": 28,
    },
    {
        "id": "post_2",
        "authorID": "peer_faisal",
        "title": "My data science SOP was too generic at first",
        "body": "The first draft sounded polished but weak. What fixed it was replacing vague motivation with one specific project and one clear job target.",
        "kind": "Admit Story",
        "country": "United Kingdom",
        "subjectArea": "Data Science",
        "degreeLevel": "Master's",
        "programID": None,
        "scholarshipID": None,
        "tags": ["sop", "evidence", "uk"],
        "moderationStatus": "Clear",
        "createdAt": "2026-03-22T09:00:00Z",
        "upvoteCount": 22,
    },
    {
        "id": "post_3",
        "authorID": "peer_nabila",
        "title": "Undergrad applicants: which deadlines mattered most in Australia?",
        "body": "I am comparing Monash and Deakin. For students applying from Bangladesh, what should I prepare first after results and IELTS?",
        "kind": "Question",
        "country": "Australia",
        "subjectArea": "Computer Science",
        "degreeLevel": "Undergraduate",
        "programID": None,
        "scholarshipID": None,
        "tags": ["undergrad", "deadlines", "australia"],
        "moderationStatus": "Clear",
        "createdAt": "2026-03-25T07:00:00Z",
        "upvoteCount": 14,
    },
    {
        "id": "post_4",
        "authorID": "peer_rafi",
        "title": "Finance applicants: do not ignore the visa prep date",
        "body": "The official application deadline is not the only date that matters. If funding is tight, late visa prep can quietly destroy your timeline.",
        "kind": "Scholarship Advice",
        "country": "United States",
        "subjectArea": "Finance",
        "degreeLevel": "Master's",
        "programID": None,
        "scholarshipID": None,
        "tags": ["visa", "finance", "timeline"],
        "moderationStatus": "Clear",
        "createdAt": "2026-03-28T08:30:00Z",
        "upvoteCount": 31,
    },
    {
        "id": "post_5",
        "authorID": "peer_mahi",
        "title": "Netherlands budget question for economics applicants",
        "body": "Is anyone from Bangladesh seeing realistic funding paths for economics in the Netherlands, or is self-funding the only serious route?",
        "kind": "Question",
        "country": "Netherlands",
        "subjectArea": "Economics",
        "degreeLevel": "Undergraduate",
        "programID": None,
        "scholarshipID": None,
        "tags": ["netherlands", "economics", "budget"],
        "moderationStatus": "Clear",
        "createdAt": "2026-03-29T11:00:00Z",
        "upvoteCount": 11,
    },
    {
        "id": "post_6",
        "authorID": "peer_tahsin",
        "title": "Hong Kong scholarship essays reward specificity",
        "body": "My first essay was full of ambition but thin on evidence. The accepted version focused on two concrete achievements and one clear reason Hong Kong fit my plan.",
        "kind": "Scholarship Advice",
        "country": "Hong Kong",
        "subjectArea": "Business Analytics",
        "degreeLevel": "Undergraduate",
        "programID": None,
        "scholarshipID": None,
        "tags": ["hongkong", "scholarship", "essay"],
        "moderationStatus": "Clear",
        "createdAt": "2026-03-30T12:00:00Z",
        "upvoteCount": 19,
    },
]


peer_replies = [
    {
        "id": "reply_1",
        "postID": "post_3",
        "authorID": "peer_nabila",
        "body": "Answering my own question after talking to admissions: start with passport, English score, and a budget check before you chase extra schools.",
        "createdAt": "2026-03-27T09:00:00Z",
        "moderationStatus": "Clear",
        "isAcceptedAnswer": False,
    },
    {
        "id": "reply_2",
        "postID": "post_3",
        "authorID": "peer_tahsin",
        "body": "From Bangladesh, the most useful early sequence was: shortlist, IELTS, passport, scholarship scan, then transcripts. That prevented rework later.",
        "createdAt": "2026-03-27T12:00:00Z",
        "moderationStatus": "Clear",
        "isAcceptedAnswer": True,
    },
    {
        "id": "reply_3",
        "postID": "post_5",
        "authorID": "peer_rafi",
        "body": "For most applicants, Netherlands economics is much easier to justify when annual budget is honestly modeled first. I would not rely on weak scholarship data.",
        "createdAt": "2026-03-30T10:00:00Z",
        "moderationStatus": "Clear",
        "isAcceptedAnswer": True,
    },
]


peer_artifacts = [
    {
        "id": "artifact_1",
        "authorID": "peer_sadia",
        "programID": sample_program_a["id"],
        "title": "TMU analytics SOP notes",
        "summary": "A verified student summary of what made the SOP credible enough to survive internal review.",
        "kind": "SOP Sample",
        "country": "Canada",
        "subjectArea": "Business Analytics",
        "degreeLevel": "Master's",
        "verificationStatus": "Verified Student",
        "moderationStatus": "Clear",
        "createdAt": "2026-03-21T10:00:00Z",
        "bulletHighlights": [
            "Used one strong project instead of three weak examples.",
            "Explained why Canada fit the labor-market goal, not just the brand.",
            "Mentioned budget pressure honestly without turning it into self-pity.",
        ],
    },
    {
        "id": "artifact_2",
        "authorID": "peer_faisal",
        "programID": None,
        "title": "UK data science admit timeline",
        "summary": "A verified admit timeline showing which tasks mattered and which ones were noise.",
        "kind": "Decision Timeline",
        "country": "United Kingdom",
        "subjectArea": "Data Science",
        "degreeLevel": "Master's",
        "verificationStatus": "Verified Admit",
        "moderationStatus": "Clear",
        "createdAt": "2026-03-23T09:00:00Z",
        "bulletHighlights": [
            "Started the SOP before chasing too many schools.",
            "Asked for references early because recommenders caused the biggest delay.",
            "Treated scholarship deadlines as distinct from application deadlines.",
        ],
    },
    {
        "id": "artifact_3",
        "authorID": "peer_tahsin",
        "programID": None,
        "title": "Hong Kong scholarship essay debrief",
        "summary": "A verified undergrad student breakdown of what changed between a weak and strong scholarship essay.",
        "kind": "Scholarship Essay",
        "country": "Hong Kong",
        "subjectArea": "Business Analytics",
        "degreeLevel": "Undergraduate",
        "verificationStatus": "Verified Student",
        "moderationStatus": "Clear",
        "createdAt": "2026-03-30T12:30:00Z",
        "bulletHighlights": [
            "Specific achievements mattered more than polished language alone.",
            "Explained why funding changed feasibility in precise terms.",
            "Linked Hong Kong to a concrete next step, not abstract global exposure.",
        ],
    },
    {
        "id": "artifact_4",
        "authorID": "peer_rafi",
        "programID": None,
        "title": "US finance interview notes",
        "summary": "An alumni note on which questions repeated across finance interview calls.",
        "kind": "Interview Debrief",
        "country": "United States",
        "subjectArea": "Finance",
        "degreeLevel": "Master's",
        "verificationStatus": "Verified Alumni",
        "moderationStatus": "Clear",
        "createdAt": "2026-03-28T09:00:00Z",
        "bulletHighlights": [
            "Expect direct questions about why the country matters for your plan.",
            "Be ready to explain the funding plan without sounding uncertain.",
            "Concrete post-degree goals reduce interviewer skepticism.",
        ],
    },
]


def write_json(name: str, payload):
    output = SEED_DIR / name
    output.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"wrote {output.relative_to(ROOT)}")


def main():
    SEED_DIR.mkdir(parents=True, exist_ok=True)
    write_json("universities.json", universities)
    write_json("programs.json", programs)
    write_json("program_requirements.json", requirements)
    write_json("program_deadlines.json", deadlines)
    write_json("scholarships.json", scholarships)
    write_json("peer_profiles.json", peer_profiles)
    write_json("peer_posts.json", peer_posts)
    write_json("peer_replies.json", peer_replies)
    write_json("peer_artifacts.json", peer_artifacts)
    write_json("sample_profile.json", sample_profile)
    write_json("sample_applications.json", sample_applications)
    write_json("sample_tasks.json", sample_tasks)


if __name__ == "__main__":
    main()
