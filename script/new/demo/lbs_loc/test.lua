module(...,package.seeall)
require"lbsloc"

--[[
��һ��ʹ�û�վ��ȡ��γ�ȵĹ��ܣ����밴�����²��������
1����Luat������ƽ̨ǰ��ҳ�棺https://iot.openluat.com/
2��ע���û�
3��ע���û�֮�󣬴���һ������Ŀ
4����������Ŀ֮�󣬽�����Ŀ
5��������Ŀ�󣬵����ߵ���Ŀ��Ϣ���ұ߻������Ϣ���ݣ��ҵ�ProductKey����ProductKey�����ݣ���ֵ�����ļ��е�ProductKey����
6����ѯһ���豸��IMEI��ģ���ǩ�Ͼ���IMEI
7���ڵ�5����ҳ�棬�����ߵ��豸������Ȼ���ٵ���ұߵ������豸���ڵ������У��豸��������䣬�豸IMEI�������6����õ�IMEI
�Ժ�������豸��ʹ�ô˹���ʱ���ظ�����ĵ�6���͵�7������
]]

--�û���������Լ�����Ŀ��Ϣ���޸����������ֵ
local ProductKey = "v32xEAKsGTIEQxtqgwCldp5aPlcnPs3K"

--�Ƿ��ѯGPSλ���ַ�����Ϣ
local qrylocation

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������testǰ׺
����  ����
����ֵ����
]]
local function print(...)
	_G.print("test",...)
end

--[[
��������qrygps
����  ����ѯGPSλ������
����  ����
����ֵ����
]]
local function qrygps()
	qrylocation = not qrylocation
	lbsloc.request(getgps,qrylocation)
end

--[[
��������getgps
����  ����ȡ��γ�Ⱥ�Ļص�����
����  ��
		result��number���ͣ���ȡ�����0��ʾ�ɹ��������ʾʧ�ܡ��˽��Ϊ0ʱ�����3��������������
		lat��string���ͣ�γ�ȣ���������3λ������031.2425864
		lng��string���ͣ����ȣ���������3λ������121.4736522
		location��string���ͣ�GB2312�����λ���ַ���������lbsloc.request��ѯ��γ�ȣ�����ĵڶ�������Ϊtrueʱ���ŷ��ر�����
����ֵ����
]]
function getgps(result,lat,lng,location)
	print("getgps",result,lat,lng,location)
	--��ȡ��γ�ȳɹ�
	if result==0 then
	--ʧ��
	else
	end
	sys.timer_start(qrygps,20000)
end

--���ò�Ʒ��Կ
lbsloc.setup(ProductKey)
--20���ȥ��ѯ��γ�ȣ���ѯ���ͨ���ص�����getgps����
sys.timer_start(qrygps,20000)