import moment from "moment";
import simpleGit from "simple-git";
import Random from "random";
import jsonfile from "jsonfile";

const FilePath = "./data.json";
const git = simpleGit();

const makeCommit = async (n) => {
    if (n === 0) {
        try {
            console.log("All commits created. Attempting to push...");
            // Option 1: Try normal push first
            await git.push("origin", "main");
            console.log("Push successful!");
        } catch (error) {
            console.log("Normal push failed:", error.message);
            try {
                // Option 2: Pull and merge, then push
                console.log("Trying to pull and merge...");
                await git.pull("origin", "main", { "--allow-unrelated-histories": null });
                await git.push("origin", "main");
                console.log("Push successful after pull!");
            } catch (pullError) {
                console.log("Pull and push failed:", pullError.message);
                // Option 3: Force push (WARNING: This overwrites remote history!)
                console.log("Attempting force push... (This will overwrite remote history)");
                await git.push([ "-f", "origin", "main" ]);
                console.log("Force push successful!");
            }
        }
        return;
    }

    const x = Random.int(0, 54);
    const y = Random.int(0, 6);
    const year = Random.int(1, 3);
    const date = moment().subtract(year, "y").add(1, "d").add(x, "w").add(y, "d").format();

    const data = {
        date: date
    };

    console.log(`Creating commit ${200 - n + 1}/200 for date: ${date}`);

    jsonfile.writeFile(FilePath, data, async () => {
        const env = {
            ...process.env,
            GIT_AUTHOR_DATE: date,
            GIT_COMMITTER_DATE: date,
        };

        await git.add([ FilePath ]);

        // Set environment variables and commit
        await git.env(env).commit("Update data.json", [ FilePath ]);

        makeCommit(n - 1);
    });
};

// Alternative: Create all commits first, then push once at the end
const makeAllCommitsFirst = async (n) => {
    console.log("Creating all commits first, then pushing at the end...");

    for (let i = n; i > 0; i--) {
        const x = Random.int(0, 54);
        const y = Random.int(0, 6);
        const year = Random.int(1, 3);
        const date = moment().subtract(year, "y").add(1, "d").add(x, "w").add(y, "d").format();

        const data = { date: date };

        console.log(`Creating commit ${n - i + 1}/${n} for date: ${date}`);

        jsonfile.writeFileSync(FilePath, data);

        const env = {
            ...process.env,
            GIT_AUTHOR_DATE: date,
            GIT_COMMITTER_DATE: date,
        };

        await git.add([ FilePath ]);
        await git.env(env).commit("Update data.json", [ FilePath ]);
    }

    // Now push all at once
    try {
        console.log("All commits created. Pushing to remote...");
        await git.push([ "-f", "origin", "main" ]); // Force push since we're rewriting history
        console.log("All commits pushed successfully!");
    } catch (error) {
        console.error("Push failed:", error.message);
    }
};

// Choose which approach to use:
makeCommit(200);
// OR: makeAllCommitsFirst(200);