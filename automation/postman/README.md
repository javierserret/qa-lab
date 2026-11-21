# API tests with Newman

The pipeline runs `qa-lab.postman_collection.json`: health, successful login,
invalid login, and products (14 assertions across four requests).

With the backend running locally on port 3001:

```sh
cd automation/postman
npm ci
npm test
```

Jenkins runs the same command with an environment override:

```sh
npm test -- --env-var baseUrl=http://backend-api:3001
```

Inside Docker, `localhost` refers to the Jenkins container; `backend-api` is
the backend service on the Compose network. The exported local environment
continues to use `http://localhost:3001`.

Newman prints results in the console and writes `test-results/results.xml`.
Jenkins publishes this JUnit report with the Playwright and Appium results,
and archives the XML under Build Artifacts. Failed assertions or request
errors fail the API stage and skip subsequent test stages.

After editing requests in Postman, export the collection in v2.1 format to
`qa-lab.postman_collection.json` so Jenkins runs those changes.
