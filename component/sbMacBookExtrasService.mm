/*
//
// BEGIN SONGBIRD GPL
//
// This file is part of the Songbird web player.
//
// Copyright(c) 2005-2009 POTI, Inc.
// http://songbirdnest.com
//
// This file may be licensed under the terms of of the
// GNU General Public License Version 2 (the "GPL").
//
// Software distributed under the License is distributed
// on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either
// express or implied. See the GPL for the specific language
// governing rights and limitations.
//
// You should have received a copy of the GPL along with this
// program. If not, go to http://www.gnu.org/licenses/gpl.html
// or write to the Free Software Foundation, Inc.,
// 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
//
// END SONGBIRD GPL
//
*/

#include "sbMacBookExtrasService.h"

#include <nsComponentManagerUtils.h>
#include <nsICategoryManager.h>
#include <nsIObserverService.h>
#include <nsServiceManagerUtils.h>

#include <sbIMediacoreManager.h>
#include <sbIMediacorePlaybackControl.h>

void
SystemPowerCallBack(void* refCon,
                    io_service_t service,
                    natural_t messageType,
                    void* messageArgument)
{
  if (messageType == kIOMessageSystemWillSleep) {
    sbMacBookExtrasService* service =
        static_cast<sbMacBookExtrasService*>(refCon);
    service->Pause();
  }
}

OSStatus
Listener(AudioDeviceID deviceId,
         UInt32 channel,
         Boolean isInput,
         AudioDevicePropertyID propertyId,
         void* clientData)
{
  sbMacBookExtrasService* service =
      static_cast<sbMacBookExtrasService*>(clientData);
  service->Pause();
  return noErr;
}

NS_IMPL_ISUPPORTS1(sbMacBookExtrasService, nsIObserver)

sbMacBookExtrasService::sbMacBookExtrasService()
{
}

sbMacBookExtrasService::~sbMacBookExtrasService()
{
}

nsresult
sbMacBookExtrasService::Pause()
{
  nsresult rv;
  nsCOMPtr<sbIMediacoreManager> manager =
    do_GetService("@songbirdnest.com/Songbird/Mediacore/Manager;1", &rv);
  NS_ENSURE_SUCCESS(rv, rv);

  nsCOMPtr<sbIMediacorePlaybackControl> playbackControl;
  rv = manager->GetPlaybackControl(getter_AddRefs(playbackControl));
  NS_ENSURE_SUCCESS(rv, rv);

  playbackControl->Pause();
  return NS_OK;
}

nsresult
sbMacBookExtrasService::Start()
{
  // Register for audio device data source callbacks.
  UInt32 size = sizeof(AudioDeviceID);
  OSStatus err;
  err = AudioHardwareGetProperty(kAudioHardwarePropertyDefaultOutputDevice,
                                 &size,
                                 &m_audioDeviceId);
  NS_ENSURE_TRUE((err == noErr), NS_ERROR_FAILURE);

  err = AudioDeviceAddPropertyListener(m_audioDeviceId,
                                       0,
                                       0x00,
                                       kAudioDevicePropertyDataSource,
                                       Listener,
                                       (void*) this);
  NS_ENSURE_TRUE((err == noErr), NS_ERROR_FAILURE);

  // Register for power management notificatios, see:
  // http://developer.apple.com/qa/qa2004/qa1340.html
  m_rootPort = IORegisterForSystemPower(this,
                                        &m_notifyPortRef,
                                        SystemPowerCallBack,
                                        &m_notifierObject);
  NS_ENSURE_TRUE((m_rootPort != 0), NS_ERROR_FAILURE);

  CFRunLoopAddSource(CFRunLoopGetCurrent(),
                     IONotificationPortGetRunLoopSource(m_notifyPortRef),
                     kCFRunLoopCommonModes);

  return NS_OK;
}

nsresult
sbMacBookExtrasService::Stop()
{
  OSStatus err;
  err = AudioDeviceRemovePropertyListener(m_audioDeviceId,
                                          0,
                                          0x00,
                                          kAudioDevicePropertyDataSource,
                                          Listener);
  NS_ENSURE_TRUE((err == noErr), NS_ERROR_FAILURE);

  CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                        IONotificationPortGetRunLoopSource(m_notifyPortRef),
                        kCFRunLoopCommonModes);
  IODeregisterForSystemPower(&m_notifierObject);
  IOServiceClose(m_rootPort);
  IONotificationPortDestroy(m_notifyPortRef);
  return NS_OK;
}

NS_IMETHODIMP
sbMacBookExtrasService::Init()
{
  nsresult rv;
  nsCOMPtr<nsIObserverService> observerService =
    do_GetService("@mozilla.org/observer-service;1", &rv);
  NS_ENSURE_SUCCESS(rv, rv);

  rv = observerService->AddObserver(this, "final-ui-startup", PR_FALSE);
  NS_ENSURE_SUCCESS(rv, rv);

  rv = observerService->AddObserver(this, "quit-application-granted",
                                    PR_FALSE);
  NS_ENSURE_SUCCESS(rv, rv);

  return NS_OK;
}

NS_IMETHODIMP
sbMacBookExtrasService::Observe(nsISupports* aSubject,
                                const char* aTopic,
                                const PRUnichar* aData)
{
  NS_ENSURE_ARG_POINTER(aTopic);

  if (strcmp(aTopic, "final-ui-startup") == 0) {
    nsresult rv = Start();
    NS_ENSURE_SUCCESS(rv, rv);
  }
  else if (strcmp(aTopic, "quit-application-granted") == 0) {
    nsresult rv;
    rv = Stop();
    NS_ENSURE_SUCCESS(rv, rv);

    nsCOMPtr<nsIObserverService> observerService =
      do_GetService("@mozilla.org/observer-service;1", &rv);
    NS_ENSURE_SUCCESS(rv, rv);

    rv = observerService->RemoveObserver(this, "final-ui-startup");
    NS_ENSURE_SUCCESS(rv, rv);

    rv = observerService->RemoveObserver(this, aTopic);
    NS_ENSURE_SUCCESS(rv, rv);
  }

  return NS_OK;
}

/* static */ NS_METHOD
sbMacBookExtrasService::RegisterSelf(nsIComponentManager* aCompMgr,
                                     nsIFile* aFile,
                                     const char* aLoaderStr,
                                     const char* aType,
                                     const nsModuleComponentInfo* aInfo)
{
  NS_ENSURE_ARG_POINTER(aCompMgr);
  NS_ENSURE_ARG_POINTER(aFile);
  NS_ENSURE_ARG_POINTER(aLoaderStr);
  NS_ENSURE_ARG_POINTER(aType);
  NS_ENSURE_ARG_POINTER(aInfo);

  nsresult rv;
  nsCOMPtr<nsICategoryManager> catMgr =
    do_GetService(NS_CATEGORYMANAGER_CONTRACTID, &rv);
  NS_ENSURE_SUCCESS(rv, rv);

  rv = catMgr->AddCategoryEntry("app-startup",
                                SONGBIRD_MACBOOKEXTRAS_CLASSNAME,
                                "service,"
                                SONGBIRD_MACBOOKEXTRAS_CONTRACTID,
                                PR_TRUE, PR_TRUE, nsnull);
  return rv;
}
