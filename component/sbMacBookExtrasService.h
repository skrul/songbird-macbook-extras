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

#ifndef sbMacBookExtrasService_h_
#define sbMacBookExtrasService_h_

#include <nsIComponentManager.h>
#include <nsIGenericFactory.h>
#include <nsIObserver.h>

#include <CoreAudio/CoreAudio.h>
#include <IOKit/IOMessage.h>
#include <IOKit/pwr_mgt/IOPMLib.h>

class sbMacBookExtrasService : public nsIObserver
{
public:
  sbMacBookExtrasService();
  virtual ~sbMacBookExtrasService();

  NS_DECL_ISUPPORTS
  NS_DECL_NSIOBSERVER

  NS_IMETHOD Init();

  nsresult Pause();

  static NS_METHOD RegisterSelf(nsIComponentManager* aCompMgr,
                                nsIFile* aPath,
                                const char* aLoaderStr,
                                const char* aType,
                                const nsModuleComponentInfo* aInfo);
private:
  nsresult Start();
  nsresult Stop();

  AudioDeviceID m_audioDeviceId;
  io_connect_t m_rootPort;
  io_object_t m_notifierObject;
  IONotificationPortRef m_notifyPortRef;
};

#define SONGBIRD_MACBOOKEXTRAS_CONTRACTID                 \
  "@songbirdnest.com/macbook-extras;1"
#define SONGBIRD_MACBOOKEXTRAS_CLASSNAME                  \
  "MacBook Extras"
#define SONGBIRD_MACBOOKEXTRAS_CID                        \
{ /* 4B32A942-EC13-4722-8E90-F84E61045188 */              \
  0x4B32A942,                                             \
  0xEC13,                                                 \
  0x4722,                                                 \
  {0x8E, 0x90, 0xF8, 0x4E, 0x61, 0x04, 0x51, 0x88}        \
}

#endif  // sbMacBookExtrasService_h_
