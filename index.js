import moment from "moment";
import simpleGit from "simple-git";
import jsonfile from "jsonfile";

const FilePath = "./data.json";
const git = simpleGit();

// Daily generation settings.
const COMMITS_PER_RUN = 6000;
const MIN_COMMIT_DATE_UTC = moment.utc("2016-01-01T00:00:00Z");

// Configure Git user (essential for GitHub Actions)
const setupGit = async () => {
    try {
        await git.addConfig("user.name", "GitHub Action");
        await git.addConfig("user.email", "action@github.com");

        if (process.env.GITHUB_ACTOR) {
            await git.addConfig("user.name", process.env.GITHUB_ACTOR);
            await git.addConfig(
                "user.email",
                `${process.env.GITHUB_ACTOR}@users.noreply.github.com`
            );
        }

        console.log("Git user configured successfully");
    } catch (error) {
        console.error("Failed to configure Git user:", error.message);
        throw error;
    }
};

// Generate a random timestamp from 2016-01-01 00:00:00 UTC through the
// current run time. The explicit clamp is a second safety layer so a commit
// can never be dated before January 2016 or in the future.
const getRandomCommitDate = (maxDateUtc, usedTimestamps) => {
    const minSeconds = Math.floor(MIN_COMMIT_DATE_UTC.valueOf() / 1000);
    const maxSeconds = Math.floor(maxDateUtc.valueOf() / 1000);

    if (maxSeconds < minSeconds) {
        throw new Error("Current time is earlier than the minimum commit date.");
    }

    let randomSeconds;
    do {
        randomSeconds = Math.floor(
            Math.random() * (maxSeconds - minSeconds + 1)
        ) + minSeconds;
    } while (usedTimestamps.has(randomSeconds));

    usedTimestamps.add(randomSeconds);

    const safeSeconds = Math.min(
        Math.max(randomSeconds, minSeconds),
        maxSeconds
    );

    return moment
        .utc(safeSeconds * 1000)
        .format("YYYY-MM-DDTHH:mm:ss[Z]");
};

const pushCommits = async () => {
    try {
        console.log("All commits created. Attempting to push...");

        // Configure remote URL with the GitHub Actions token if available.
        if (process.env.GITHUB_TOKEN && process.env.GITHUB_REPOSITORY) {
            const remoteUrl = `https://${process.env.GITHUB_TOKEN}@github.com/${process.env.GITHUB_REPOSITORY}.git`;
            await git.removeRemote("origin").catch(() => {});
            await git.addRemote("origin", remoteUrl);
            console.log("Authenticated remote configured");
        }

        await git.push("origin", "main");
        console.log("Push successful!");
    } catch (error) {
        console.log("Normal push failed:", error.message);
        try {
            console.log("Attempting force push...");
            await git.push(["-f", "origin", "main"]);
            console.log("Force push successful!");
        } catch (forceError) {
            console.error("All push attempts failed:", forceError.message);
            console.log("Please check:");
            console.log("1. Workflow has 'contents: write' permission");
            console.log("2. Repository settings allow Actions to write");
            process.exit(1);
        }
    }
};

const makeCommits = async (count) => {
    // Capture 'now' once. Every generated timestamp must be <= this value.
    const runUpperBoundUtc = moment.utc();
    const usedTimestamps = new Set();

    console.log(`Creating ${count} commits.`);
    console.log(
        `Allowed date range: ${MIN_COMMIT_DATE_UTC.format("YYYY-MM-DDTHH:mm:ss[Z]")} to ${runUpperBoundUtc.format("YYYY-MM-DDTHH:mm:ss[Z]")}`
    );

    for (let i = 1; i <= count; i++) {
        const date = getRandomCommitDate(runUpperBoundUtc, usedTimestamps);
        const data = { date };

        console.log(`Creating commit ${i}/${count} for date: ${date}`);

        await jsonfile.writeFile(FilePath, data);

        const env = {
            ...process.env,
            GIT_AUTHOR_DATE: date,
            GIT_COMMITTER_DATE: date,
        };

        await git.add([FilePath]);
        await git.env(env).commit("Update data.json", [FilePath]);
    }

    await pushCommits();
};

const main = async () => {
    await setupGit();
    await makeCommits(COMMITS_PER_RUN);
};

main().catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
});
