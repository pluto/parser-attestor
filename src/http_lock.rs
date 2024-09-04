use super::*;

#[derive(Debug, Serialize, Deserialize)]
struct HttpData {
    request: Request,
    response: Response,
}

#[derive(Debug, Serialize, Deserialize)]
struct Request {
    method: String,
    target: String,
    version: String,
    headers: Vec<(String, String)>,
}

#[derive(Debug, Serialize, Deserialize)]
struct Response {
    version: String,
    status: String,
    message: String,
    headers: Vec<(String, serde_json::Value)>,
}

// TODO: This needs to codegen a circuit now.
pub fn http_lock(args: HttpLockArgs) -> Result<(), Box<dyn Error>> {
    let data = std::fs::read(&args.lockfile)?;
    let http_data: HttpData = serde_json::from_slice(&data)?;

    dbg!(http_data);

    Ok(())
}
