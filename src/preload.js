const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('sawitHeight', {
  selectPointCloud: () => ipcRenderer.invoke('dialog:pointCloud'),
  selectTreePoints: () => ipcRenderer.invoke('dialog:treePoints'),
  selectDtm: () => ipcRenderer.invoke('dialog:dtm'),
  selectOutputFolder: () => ipcRenderer.invoke('dialog:outputFolder'),
  selectRscript: () => ipcRenderer.invoke('dialog:rscript'),
  getState: () => ipcRenderer.invoke('app:getState'),
  saveSettings: (settings) => ipcRenderer.invoke('app:saveSettings', settings),
  detectEnvironment: (rscriptPath) => ipcRenderer.invoke('environment:detect', rscriptPath),
  checkEnvironment: (rscriptPath) => ipcRenderer.invoke('environment:check', rscriptPath),
  installPackages: (rscriptPath) => ipcRenderer.invoke('environment:installPackages', rscriptPath),
  validateAnalysis: (payload) => ipcRenderer.invoke('analysis:validate', payload),
  startAnalysis: (payload) => ipcRenderer.invoke('analysis:start', payload),
  cancelAnalysis: () => ipcRenderer.invoke('analysis:cancel'),
  openPath: (targetPath) => ipcRenderer.invoke('shell:openPath', targetPath),
  showItem: (targetPath) => ipcRenderer.invoke('shell:showItem', targetPath),
  onAnalysisEvent: (callback) => {
    const handler = (_event, payload) => callback(payload);
    ipcRenderer.on('analysis:event', handler);
    return () => ipcRenderer.removeListener('analysis:event', handler);
  }
});
