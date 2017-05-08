--[[
ģ�����ƣ���վ��Ϣת��γ��
ģ�鹦�ܣ����ӻ�վ��λ��̨���ϱ����վ����̨����̨���ؾ�γ��
ģ������޸�ʱ�䣺2017.05.05
]]

--����ģ��,����������
local base = _G
local string = require"string"
local table = require"table"
local lpack = require"pack"
local bit = require"bit"
local sys  = require"sys"
local link = require"link"
local misc = require"misc"
local common = require"common"
local net = require"net"
module(...)

--���س��õ�ȫ�ֺ���������
local print,tonumber,pairs = base.print,base.tonumber,base.pairs
local slen,sbyte,ssub = string.len,string.byte,string.sub

--��Luat�ƺ�̨�ϴ�����Ŀʱ���ɵ�ProductKey
local productkey
local PROTOCOL,SERVER,PORT = "UDP","bs.openluat.com","12411"

--GET����ȴ�ʱ��
local CMD_GET_TIMEOUT = 2000
--�����(��ʽ����) ��һ��ʱ���������»�ȡ
local ERROR_PACK_TIMEOUT = 2000
-- ÿ��GET�������Դ���
local CMD_GET_RETRY_TIMES = 3
--socket id
local lid
--����״̬�������Ѿ�������Ϊfalse����nil������Ϊtrue
local linksta,usercb,userlocstr
--getretries����ȡÿ�����Ѿ����ԵĴ���
local getretries = 0

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������lbslocǰ׺
����  ����
����ֵ����
]]
local function print(...)
	base.print("lbsloc",...)
end

--[[
��������retry
����  ����������е����Զ���
����  ��
����ֵ����
]]
local function retry()
	print("retry",getretries)
	--���Դ�����1
	getretries = getretries + 1
	if getretries < CMD_GET_RETRY_TIMES then
		-- δ�����Դ���,��������
		reqget()
	else
		-- �������Դ���,����ʧ��
		reqend(false)
	end
end

local function encellinfo(s)
	local ret,t,mcc,mnc,lac,ci,rssi,k,v,m,n,cntrssi = "",{}
	print("encellinfo",s)
	for mcc,mnc,lac,ci,rssi in string.gmatch(s,"(%d+)%.(%d+)%.(%d+)%.(%d+)%.(%d+);") do
		mcc,mnc,lac,ci,rssi = tonumber(mcc),tonumber(mnc),tonumber(lac),tonumber(ci),(tonumber(rssi) > 31) and 31 or tonumber(rssi)
		local handle = nil
		for k,v in pairs(t) do
			if v.lac == lac and v.mcc == mcc and v.mnc == mnc then
				if #v.rssici < 8 then
					table.insert(v.rssici,{rssi=rssi,ci=ci})
				end
				handle = true
				break
			end
		end
		if not handle then
			table.insert(t,{mcc=mcc,mnc=mnc,lac=lac,rssici={{rssi=rssi,ci=ci}}})
		end
	end
	for k,v in pairs(t) do
		ret = ret .. lpack.pack(">HHb",v.lac,v.mcc,v.mnc)
		for m,n in pairs(v.rssici) do
			cntrssi = bit.bor(bit.lshift(((m == 1) and (#v.rssici-1) or 0),5),n.rssi)
			ret = ret .. lpack.pack(">bH",cntrssi,n.ci)
		end
	end

	return string.char(#t)..ret
end

local function bcd(d,n)
	local l = slen(d or "")
	local num
	local t = {}

	for i=1,l,2 do
		num = tonumber(ssub(d,i,i+1),16)

		if i == l then
			num = 0xf0+num
		else
			num = (num%0x10)*0x10 + num/0x10
		end

		table.insert(t,num)
	end

	local s = string.char(base.unpack(t))

	l = slen(s)

	if l < n then
		s = s .. string.rep("\255",n-l)
	elseif l > n then
		s = ssub(s,1,n)
	end

	return s
end

--460.01.6311.49234.30;460.01.6311.49233.23;460.02.6322.49232.18;
local function getcellcb(s)
	print("getcellcb")
	local sn,sninvalid,len,i = misc.getsn(),""
	len = slen(sn)
	for i=1,len do
		sninvalid = sninvalid.."0"
	end
	local status = (sn==sninvalid and 0 or 1) + (userlocstr and 1 or 0)*2
	local dsecret = ""
	if sn~=sninvalid then
		dsecret = lpack.pack("bA",slen(sn),sn)
	end
	link.send(lid,lpack.pack("bAbAAA",slen(productkey),productkey,status,dsecret,bcd(misc.getimei(),8),encellinfo(s)))
	--������CMD_GET_TIMEOUT��������ԡ���ʱ��
	sys.timer_start(retry,CMD_GET_TIMEOUT)
end

--[[
��������reqget
����  �����ͻ�վ��Ϣ��������
����  ����
����ֵ����
]]
function reqget()
	print("reqget")
	net.getmulticell(getcellcb)
end

--[[
��������reqend
����  ����ȡ����
����  ��
		suc�������trueΪ�ɹ�������Ϊʧ��
����ֵ����
]]
function reqend(suc)
	print("reqend",suc)
	if not suc then
		local tmpcb=usercb
		usercb=nil
		sys.timer_stop(tmoutfnc)
		if tmpcb then tmpcb(4) end
	end
	--ֹͣ���Զ�ʱ��
	sys.timer_stop(retry)
	--�Ͽ�����
	link.close(lid)
	linksta = false
end

--[[
��������nofity
����  ��socket״̬�Ĵ�������
����  ��
        id��socket id��������Ժ��Բ�����
        evt����Ϣ�¼�����
		val�� ��Ϣ�¼�����
����ֵ����
]]
local function nofity(id,evt,val)
	--���ӽ��
	if evt == "CONNECT" then
		--���ӳɹ�
		if val == "CONNECT OK" then
			getretries = 0
			reqget()
		--����ʧ��
		else
			reqend(false)
		end
	--���ӱ����Ͽ�
	elseif evt == "STATE" and (val=="CLOSED" or val=="SHUTED") then
		reqend(false)
	end
end

local function unbcd(d)
	local byte,v1,v2
	local t = {}

	for i=1,slen(d) do
		byte = sbyte(d,i)
		v1,v2 = bit.band(byte,0x0f),bit.band(bit.rshift(byte,4),0x0f)

		if v1 == 0x0f then break end
		table.insert(t,v1)

		if v2 == 0x0f then break end
		table.insert(t,v2)
	end

	return table.concat(t)
end

--[[
��������rcv
����  ��socket�������ݵĴ�������
����  ��
        id ��socket id��������Ժ��Բ�����
        data�����յ�������
����ֵ����
]]
local function rcv(id,s)
	print("rcv",slen(s),(slen(s)<270) and common.binstohexs(s) or "")
	if slen(s)>=11 then return end
	reqend(true)
	local tmpcb=usercb
	usercb=nil
	sys.timer_stop(tmoutfnc)
	if sbyte(s,1)~=0 then
		if tmpcb then tmpcb(3) end
	else
		local lat,lng = unbcd(ssub(s,2,6)),unbcd(ssub(s,7,11))
		if tmpcb then tmpcb(0,ssub(lat,1,3).."."..ssub(lat,4,-1),ssub(lng,1,3).."."..ssub(lng,4,-1),common.ucs2betogb2312(ssub(s,13,-1))) end
	end	
end

function tmoutfnc()
	print("tmoutfnc")
	local tmpcb=usercb
	usercb=nil
	if tmpcb then tmpcb(2) end
end

--[[
��������request
����  �������ȡ��γ������
����  ��
        cb����ȡ����γ�Ȼ��߳�ʱ��Ļص�������������ʽΪ��cb(result,lat,lng,location)		
		locstr���Ƿ�֧��λ���ַ������أ�true֧�֣�false����nil��֧�֣�Ĭ�ϲ�֧��
		tmout����ȡ��γ�ȳ�ʱʱ�䣬��λ�룬Ĭ��20��
����ֵ����
]]
function request(cb,locstr,tmout)
	print("request",cb,tmout,locstr,usercb,linksta)
	if usercb then print("request usercb err") cb(1) end
	if not linksta then
		lid = link.open(nofity,rcv,"lbsloc")
		link.connect(lid,PROTOCOL,SERVER,PORT)
		linksta = true
	end
	sys.timer_start(tmoutfnc,(tmout or 20)*1000)
	usercb,userlocstr = cb,locstr
end

--[[
��������setup
����  �����ò���
����  ��
        pkey��Luat�ƺ�̨�ϴ�����Ŀʱ���ɵ�ProductKey		
����ֵ����
]]
function setup(pkey)
	print("setup",pkey)
	productkey = pkey
end