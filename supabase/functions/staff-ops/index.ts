import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const jsonHeaders = { "Content-Type": "application/json" };

type StaffActionPayload = {
  action: "update_report_status" | "update_verification_status" | "mark_program_freshness";
  reportId?: string;
  requestId?: string;
  userId?: string;
  programId?: string;
  status?: string;
  verificationStatus?: string;
  dataFreshness?: string;
  updatedAt?: string;
};

serve(async (request) => {
  if (request.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed." }), {
      status: 405,
      headers: jsonHeaders,
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const staffEmails = (Deno.env.get("STAFF_ADMIN_EMAILS") ?? "")
    .split(",")
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean);

  if (!supabaseUrl || !serviceRoleKey) {
    return new Response(JSON.stringify({ error: "Missing Supabase function secrets." }), {
      status: 500,
      headers: jsonHeaders,
    });
  }

  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "Missing bearer token." }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  const accessToken = authHeader.replace("Bearer ", "");
  const anonClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
  });
  const serviceClient = createClient(supabaseUrl, serviceRoleKey);

  const { data: userData, error: userError } = await anonClient.auth.getUser();
  if (userError || !userData.user?.email) {
    return new Response(JSON.stringify({ error: "Could not validate the authenticated staff user." }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  const userEmail = userData.user.email.toLowerCase();
  if (!staffEmails.includes(userEmail)) {
    return new Response(JSON.stringify({ error: "This user is not allowed to perform staff actions." }), {
      status: 403,
      headers: jsonHeaders,
    });
  }

  let payload: StaffActionPayload;
  try {
    payload = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON payload." }), {
      status: 400,
      headers: jsonHeaders,
    });
  }

  const auditPayload = { ...payload, actorEmail: userEmail };

  switch (payload.action) {
    case "update_report_status": {
      if (!payload.reportId || !payload.status) {
        return badRequest("Missing report status payload.");
      }

      const { data: report, error: reportError } = await serviceClient
        .from("community_reports")
        .select('"postID"')
        .eq("id", payload.reportId)
        .maybeSingle();

      if (reportError) {
        return badRequest(reportError.message);
      }

      const { error } = await serviceClient
        .from("community_reports")
        .update({ status: payload.status })
        .eq("id", payload.reportId);
      if (error) {
        return badRequest(error.message);
      }

      if (payload.status === "Limited" && report?.postID) {
        const { error: postError } = await serviceClient
          .from("peer_posts")
          .update({ moderationStatus: "Limited" })
          .eq("id", report.postID);
        if (postError) {
          return badRequest(postError.message);
        }
      }
      break;
    }

    case "update_verification_status": {
      if (!payload.requestId || !payload.userId || !payload.verificationStatus) {
        return badRequest("Missing verification payload.");
      }

      const { error: requestError } = await serviceClient
        .from("verification_requests")
        .update({ status: "Clear" })
        .eq("id", payload.requestId);
      if (requestError) {
        return badRequest(requestError.message);
      }

      const { error: profileError } = await serviceClient
        .from("user_profiles")
        .update({ verificationStatus: payload.verificationStatus })
        .eq("id", payload.userId);
      if (profileError) {
        return badRequest(profileError.message);
      }
      break;
    }

    case "mark_program_freshness": {
      if (!payload.programId) {
        return badRequest("Missing program freshness payload.");
      }
      const { error } = await serviceClient
        .from("programs")
        .update({
          dataFreshness: payload.dataFreshness ?? "Updated Today",
          lastUpdatedAt: payload.updatedAt ?? new Date().toISOString(),
        })
        .eq("id", payload.programId);
      if (error) {
        return badRequest(error.message);
      }
      break;
    }
  }

  await serviceClient.from("admin_audit_log").insert({
    actorID: userData.user.id,
    action: payload.action,
    payload: auditPayload,
  });

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: jsonHeaders,
  });
});

function badRequest(message: string) {
  return new Response(JSON.stringify({ error: message }), {
    status: 400,
    headers: jsonHeaders,
  });
}
