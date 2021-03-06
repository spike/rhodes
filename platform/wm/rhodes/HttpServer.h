#pragma once
#include "stdafx.h"

#if (_MSC_VER == 1400)
#include "atlutil.h" //Using local copy, as 'standard' atlutil has errors
#else
#include "atlutil-vc08.h" //Using local copy, as 'standard' atlutil has errors
#endif

#include "shttpd.h"

class CHttpServer : public IWorkerThreadClient
{
  HANDLE m_hEvent;

public:
  static CHttpServer* Create();
  static CHttpServer* Instance();
  virtual ~CHttpServer(void);

  CWorkerThread<DefaultThreadTraits> m_thread;

	void ResumeThread();
	void FreezeThread();
  
  void SetMainWindow(HWND hWnd) { m_hMainWindow = hWnd; }
  
  struct shttpd_ctx	*GetHttpdContext() { return ctx; }

  //returns same buffer filled w/ path to lading page
  LPTSTR GetLoadingPage(LPTSTR buffer); 
  LPTSTR GetStartPage();
  LPTSTR GetOptionsPage();

#ifdef ENABLE_DYNAMIC_RHOBUNDLE
  const char* GetRhobundleReloadUrl();
#endif 

private:
  HWND m_hMainWindow;

  CHttpServer(void);

  HRESULT Execute(DWORD_PTR dwParam, HANDLE hObject);
  HRESULT CloseHandle(HANDLE hHandle);

  struct shttpd_ctx	*ctx;
  bool  InitHttpServer();

  bool m_bRubyInitialized;
  bool InitRubyFramework();

  LPTSTR m_pStartPage;
  LPTSTR m_pOptionsPage;	
  bool InitStartandOptionPages();

#ifdef ENABLE_DYNAMIC_RHOBUNDLE
  char* m_szRhobundleReloadUrl;
#endif
};
