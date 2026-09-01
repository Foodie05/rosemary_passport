export function createSingleFlightRefresh(refreshRequest) {
  let pendingRefresh = null;

  return function refreshSession() {
    if (!pendingRefresh) {
      pendingRefresh = Promise.resolve()
        .then(refreshRequest)
        .then((refreshed) => refreshed === true)
        .catch(() => false)
        .finally(() => {
          pendingRefresh = null;
        });
    }
    return pendingRefresh;
  };
}

export async function requestWithSessionRefresh(request, { auth = false, refreshSession } = {}) {
  const response = await request();
  if (!auth || response.status !== 401 || typeof refreshSession !== 'function') {
    return response;
  }
  if (!(await refreshSession())) {
    return response;
  }
  return request();
}
