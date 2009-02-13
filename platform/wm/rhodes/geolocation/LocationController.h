#pragma once

#include <gpsapi.h>

interface IGPSController
{
    virtual HRESULT SetGPSPosition( GPS_POSITION gps_Position ) = 0;
    virtual HRESULT SetGPSDeviceInfo( GPS_DEVICE gps_Device ) = 0;
};

class CGPSDevice
{
private:
    //Singleton instance
    static CGPSDevice * s_pInstance;

    //Device handle
    HANDLE m_hGPS_Device;

    //Event for location data updates
    HANDLE m_hNewLocationData;

    //Event for device state changes
    HANDLE m_hDeviceStateChange;

    //Thread's handle and id
    HANDLE m_hThread;
    DWORD m_dwThreadID;

    //Exit event
    HANDLE m_hExitThread;

    //Pointer to sink interface
    IGPSController * m_pController;

private:
    //Our wrapper is singleton make constructor private
    CGPSDevice(void);

    HRESULT StartThread();
    HRESULT StopThread();

    static CGPSDevice * Instance();
    static DWORD WINAPI GPSThreadProc(__opt LPVOID lpParameter);
public:

    virtual ~CGPSDevice(void);

    static HRESULT TurnOn(IGPSController * pController);
    static HRESULT TurnOff();
};

class CGPSController : public IGPSController {
	CRITICAL_SECTION m_critical_section;
	double m_latitude;
	double m_longitude;
	bool   m_knownPosition;
	bool   m_gpsIsOn;
	time_t m_timeout;
    //Singleton instance
    static CGPSController * s_pInstance;

public:
	static CGPSController* Instance();
	static void DeleteInstance();
	static void CheckTimeout();
	virtual ~CGPSController();

public:
    virtual HRESULT SetGPSPosition( GPS_POSITION gps_Position );
    virtual HRESULT SetGPSDeviceInfo( GPS_DEVICE gps_Device );
	virtual bool IsKnownPosition();
	virtual double GetLatitude();
	virtual double GetLongitude();
	virtual time_t UpdateTimeout();

	virtual void TurnGpsOn();

protected:
	void Lock();
    void Unlock();

private:
	CGPSController();
};


void show_geolocation(struct shttpd_arg *arg);