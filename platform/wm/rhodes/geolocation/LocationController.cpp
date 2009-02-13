#include "../stdafx.h"
#include "../HttpServer.h"
#include "LocationController.h"

//To test GPS on emulator, use FakeGPS (coming from WM6 SDK refresh) 

CGPSDevice * CGPSDevice::s_pInstance = NULL;

#define MAX_WAIT    5000
#define MAX_AGE     3000
#define GPS_CONTROLLER_EVENT_COUNT 3

CGPSDevice::CGPSDevice(void)
{
    m_pController = NULL;
    m_hGPS_Device = NULL;
    m_hNewLocationData = NULL;
    m_hDeviceStateChange = NULL;
    m_hExitThread = NULL;
}

CGPSDevice::~CGPSDevice(void)
{
}

CGPSDevice * CGPSDevice::Instance()
{
    if( CGPSDevice::s_pInstance == NULL )
    {
        s_pInstance = new CGPSDevice();
    }

    return CGPSDevice::s_pInstance;
}

DWORD WINAPI CGPSDevice::GPSThreadProc(__opt LPVOID lpParameter)
{
    DWORD dwRet = 0;
    GPS_POSITION gps_Position = {0};
    GPS_DEVICE gps_Device = {0};


    CGPSDevice * pDevice = (CGPSDevice*) lpParameter;

    HANDLE gpsHandles[GPS_CONTROLLER_EVENT_COUNT] = 
    {   pDevice->m_hNewLocationData, 
		pDevice->m_hDeviceStateChange,
		pDevice->m_hExitThread
    };

    gps_Position.dwSize = sizeof(gps_Position);
    gps_Position.dwVersion = GPS_VERSION_1;

    gps_Device.dwVersion = GPS_VERSION_1;
    gps_Device.dwSize = sizeof(gps_Device);

    do
    {
        dwRet = WaitForMultipleObjects(
            GPS_CONTROLLER_EVENT_COUNT, 
            gpsHandles, FALSE, INFINITE);

        if (dwRet == WAIT_OBJECT_0)
        {
            dwRet = GPSGetPosition(
                pDevice->m_hGPS_Device, 
                &gps_Position, MAX_AGE, 0);

            if (ERROR_SUCCESS != dwRet)
                continue;
            else
                pDevice->m_pController->SetGPSPosition(gps_Position);
        }
        else if (dwRet == WAIT_OBJECT_0 + 1)
        {
            dwRet = GPSGetDeviceState(&gps_Device);    

            if (ERROR_SUCCESS != dwRet)
                continue;
            else
                pDevice->m_pController->SetGPSDeviceInfo(gps_Device);
        }
        else if (dwRet == WAIT_OBJECT_0 + 2)
            break;
        else
            ASSERT(0);

    } while( TRUE );

    return 0;
}

HRESULT CGPSDevice::StartThread()
{
    HRESULT hr = E_FAIL;
    DWORD dwRet = 0;

    m_hNewLocationData = CreateEvent(NULL, FALSE, FALSE, NULL);

    if ( m_hNewLocationData )
    {
        m_hDeviceStateChange = CreateEvent(NULL, FALSE, FALSE, NULL);

        if (m_hDeviceStateChange)
        {

            m_hExitThread = CreateEvent(NULL, FALSE, FALSE, NULL);
            if (m_hExitThread)
            {

                m_hThread = ::CreateThread(NULL, NULL, 
                    GPSThreadProc, this, NULL, &m_dwThreadID);

                if ( m_hThread )
                    hr = S_OK;
            }
        }
    }

    if( FAILED(hr) )
    {
        dwRet = GetLastError();
        hr = HRESULT_FROM_WIN32(dwRet);
    }

    if (FAILED(hr))
    {
        if (m_hNewLocationData)
        {
            CloseHandle(m_hNewLocationData);
            m_hNewLocationData = NULL;
        }

        if (m_hDeviceStateChange)
        {
            CloseHandle(m_hDeviceStateChange);
            m_hDeviceStateChange = NULL;
        }

        if (m_hExitThread)
        {
            CloseHandle(m_hExitThread);
            m_hExitThread = NULL;
        }
    }
    return hr;    
}

HRESULT CGPSDevice::StopThread()
{
    HRESULT hr = E_FAIL;
    DWORD dwRet = 0;

    if( SetEvent(m_hExitThread) )
    {
        dwRet = WaitForSingleObject(m_hThread, MAX_WAIT);
        if(WAIT_OBJECT_0 == dwRet)
            hr = S_OK;
    }

    if( FAILED(hr) )
    {
        dwRet = GetLastError();
        hr = HRESULT_FROM_WIN32(dwRet);
    }

	if (m_hNewLocationData)
    {
        CloseHandle(m_hNewLocationData);
        m_hNewLocationData = NULL;
    }

    if (m_hDeviceStateChange)
    {
        CloseHandle(m_hDeviceStateChange);
        m_hDeviceStateChange = NULL;
    }

    if (m_hExitThread)
    {
        CloseHandle(m_hExitThread);
        m_hExitThread = NULL;
    }

    if (m_hThread)
    {
        CloseHandle(m_hThread);
        m_hThread = NULL;
        m_dwThreadID = 0;
    }

    return hr;
}

HRESULT CGPSDevice::TurnOn(IGPSController * pController)
{
    if( !pController )
        return E_INVALIDARG;

    CGPSDevice * pDevice = Instance();

    //We already have a device opened
    if( pDevice->m_hGPS_Device )
        return E_UNEXPECTED;

    if( pDevice->m_pController != NULL )
        return E_UNEXPECTED;

    pDevice->m_pController = pController;

    HRESULT hr = pDevice->StartThread();

    if( SUCCEEDED(hr) )
    {
        pDevice->m_hGPS_Device = GPSOpenDevice( 
            pDevice->m_hNewLocationData, 
            pDevice->m_hDeviceStateChange, 
            NULL, NULL);

        if( pDevice->m_hGPS_Device )
            hr = S_OK;
        else
            hr = HRESULT_FROM_WIN32(GetLastError());
    }

    if( FAILED(hr) )
        TurnOff();

    return hr;
}

HRESULT CGPSDevice::TurnOff()
{
    CGPSDevice * pDevice = Instance();

    if( !pDevice->m_hGPS_Device )
        return E_UNEXPECTED;    

    HRESULT hr = pDevice->StopThread();

    pDevice->m_pController = NULL;

    DWORD dwRet = GPSCloseDevice(pDevice->m_hGPS_Device);
    pDevice->m_hGPS_Device = NULL;

    if( SUCCEEDED(hr) )
    {
        if( ERROR_SUCCESS != dwRet )
            hr = HRESULT_FROM_WIN32(GetLastError());
    }

    return hr;
}

// CGPSController
#define GPS_TIMEOUT 30; //seconds

CGPSController* CGPSController::s_pInstance = NULL;

CGPSController* CGPSController::Instance() {
    if( CGPSController::s_pInstance == NULL ) {
        s_pInstance = new CGPSController();
    }
    return CGPSController::s_pInstance;
}

void CGPSController::DeleteInstance() {
    if( CGPSController::s_pInstance != NULL ) {
		delete CGPSController::s_pInstance;
	}	
}

CGPSController::CGPSController() {
	InitializeCriticalSection(&m_critical_section);
	m_knownPosition = false;
	m_gpsIsOn = false;
	m_latitude = 0;
	m_longitude = 0;

}

void CGPSController::TurnGpsOn() {
	Lock();
	if((!m_gpsIsOn) && SUCCEEDED(CGPSDevice::TurnOn(this))) {
		m_gpsIsOn = true;
		m_timeout = time(NULL)+GPS_TIMEOUT;
	}
	Unlock();
}

void CGPSController::CheckTimeout() {
	if( CGPSController::s_pInstance != NULL ) {
		CGPSController* gps = CGPSController::s_pInstance;
		gps->Lock();
		bool gpsOff = gps->m_gpsIsOn && (time(NULL)>=gps->m_timeout);
		gps->Unlock();
		if (gpsOff) {
			CGPSDevice::TurnOff();
			gps->m_gpsIsOn = false;
			gps->m_knownPosition = false;
	    gps->m_latitude = 0;
	    gps->m_longitude = 0;
		}
	}
}

CGPSController::~CGPSController() {
	DeleteCriticalSection(&m_critical_section);
	CGPSDevice::TurnOff();
}

HRESULT CGPSController::SetGPSPosition( GPS_POSITION gps_Position ) {
	Lock();
	m_knownPosition = true;
	m_latitude = gps_Position.dblLatitude;
	m_longitude = gps_Position.dblLongitude;
	Unlock();
	return S_OK;
}

HRESULT CGPSController::SetGPSDeviceInfo( GPS_DEVICE gps_Device ) {
	//Lock();
	//Unlock();
	return S_OK;
}

bool CGPSController::IsKnownPosition() {
	Lock();
	bool ret = m_knownPosition;
	Unlock();
	return ret;
}

double CGPSController::GetLatitude() {
	Lock();
	double ret = m_latitude;
	Unlock();
	return ret;
}

double CGPSController::GetLongitude() {
	Lock();
	double ret = m_longitude;
	Unlock();
	return ret;
}

time_t CGPSController::UpdateTimeout(){
	m_timeout = time(NULL)+GPS_TIMEOUT;
	return m_timeout;
}

void CGPSController::Lock() {
  EnterCriticalSection(&m_critical_section);
  //ATLTRACE(_T("CGPSController locked\n"));
}

void CGPSController::Unlock() {
  LeaveCriticalSection(&m_critical_section);
  //ATLTRACE(_T("CGPSController unlocked\n"));
}



void show_geolocation(struct shttpd_arg *arg) {
	char location[256];

	CGPSController* gps = CGPSController::Instance();
	gps->TurnGpsOn();

	gps->UpdateTimeout();
	if (gps->IsKnownPosition()) {
		double latitude = gps->GetLatitude();
		double longitude = gps->GetLongitude();
		sprintf(location,"%.4f� %s, %.4f� %s;%f;%f",
			fabs(latitude),latitude < 0 ? "South" : "North",
			fabs(longitude),longitude < 0 ? "West" : "East",
			latitude,longitude);
	} else {
		strcpy(location,"reading...;reading...;reading...");
	}

	printf("Location: %s\n",location);

	shttpd_printf(arg, "%s", "HTTP/1.1 200 OK\r\n");
	shttpd_printf(arg, "Content-Length: %lu\r\n", strlen(location));
	shttpd_printf(arg, "%s", "Connection: close\r\n");
	shttpd_printf(arg, "%s", "Pragma: no-cache\r\n" );
	shttpd_printf(arg, "%s", "Cache-Control: no-cache\r\n" );
	shttpd_printf(arg, "%s", "Expires: 0\r\n" );
	shttpd_printf(arg, "%s", "Content-Type: text/html; charset=ISO-8859-4\r\n\r\n");
	shttpd_printf(arg, "%s", location);

	arg->flags |= SHTTPD_END_OF_OUTPUT;
}

extern "C"{
double geo_latitude() {
  CGPSController* gps = CGPSController::Instance();
	gps->TurnGpsOn();
	gps->UpdateTimeout();

	return gps->GetLatitude();
}

double geo_longitude() {
  CGPSController* gps = CGPSController::Instance();
	gps->TurnGpsOn();
	gps->UpdateTimeout();

	return gps->GetLongitude();
}

int geo_known_position() {
  CGPSController* gps = CGPSController::Instance();
	gps->TurnGpsOn();
	gps->UpdateTimeout();

	return gps->IsKnownPosition();
}
}