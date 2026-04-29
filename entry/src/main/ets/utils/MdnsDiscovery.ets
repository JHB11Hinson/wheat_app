import mdns from '@ohos.net.mdns';
import { common } from '@kit.AbilityKit';

export class MdnsDiscovery {
  private static serviceType: string = '_wheat-edge._tcp';
  private static discoveryService: mdns.DiscoveryService | null = null;

  static startDiscovery(context: common.Context, onFound: (ip: string) => void) {
    MdnsDiscovery.stopDiscovery();

    MdnsDiscovery.discoveryService = mdns.createDiscoveryService(context, MdnsDiscovery.serviceType);

    MdnsDiscovery.discoveryService.on('discoveryStart', (result) => {
      console.info('MDNS_LOG', 'mDNS 搜索已启动');
    });

    MdnsDiscovery.discoveryService.on('discoveryStop', (result) => {
      console.info('MDNS_LOG', 'mDNS 搜索已停止');
    });

    MdnsDiscovery.discoveryService.on('serviceLost', (serviceInfo) => {
      console.info('MDNS_LOG', '丢失 ' + JSON.stringify(serviceInfo));
    });

    MdnsDiscovery.discoveryService.on('serviceFound', (serviceInfo: mdns.LocalServiceInfo) => {
      console.info('MDNS_LOG', '正在解析... ' + JSON.stringify(serviceInfo));

      mdns.resolveLocalService(context, serviceInfo).then((resolvedInfo: mdns.LocalServiceInfo) => {
        if (resolvedInfo && resolvedInfo.host && resolvedInfo.host.address) {
          let addr = resolvedInfo.host.address;

          // 过滤本地环回、IPv6、无效 APIPA 地址和无效网卡地址
          if (addr === '127.0.0.1' || addr.includes(':') ||
          addr.startsWith('169.254.') || addr.startsWith('192.168.0.')) {
            console.info('MDNS_LOG', '已过滤无效 IP: ' + addr);
            return;
          }

          console.info('MDNS_LOG', '成功提取IPv4: ' + addr);
          onFound(addr);
        }
      }).catch((err: Error) => {
        console.error('MDNS_LOG', '解析服务失败: ' + JSON.stringify(err));
      });
    });

    MdnsDiscovery.discoveryService.startSearchingMDNS();
    console.info('MDNS_LOG', '开始调用 startSearchingMDNS()...');
  }

  static stopDiscovery() {
    if (MdnsDiscovery.discoveryService) {
      try {
        MdnsDiscovery.discoveryService.stopSearchingMDNS();
        MdnsDiscovery.discoveryService = null;
      } catch (e) {
        console.error('MDNS_LOG', '停止搜索失败: ' + JSON.stringify(e));
      }
    }
  }
}