CREATE OR REPLACE TRIGGER IT.TB_GE_BLOQUEOS
  before delete on ge_bloqueos  
  for each row
declare
  -- local variables here
v_ok     varchar2(1);
v_pedido varchar2(400) := null;
v_respuesta varchar2(4000);
v_nro_operacion varchar2(10);
v_cta_enviada varchar2(20);

g_ok_procesar varchar2(1) := 'N';
g_cod_error number(5) := 0;
begin
   IF :old.cod_causa = 234 and nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN' then
      pag_cta.PR_OBT_CUENTA(:old.nro_cuenta);
   /* Antes de borrar un bloqueo enviar a AS-400*/ 
   --
      v_cta_enviada := lpad(pag_cta.g_ctas.COD_OFICINA,2,'0');
      if pag_cta.g_ctas.cod_modalidad = 41 and pag_cta.g_ctas.cod_moneda = 'GS' then
      v_cta_enviada := v_cta_enviada||'210100';
      elsif pag_cta.g_ctas.cod_modalidad = 31 and pag_cta.g_ctas.cod_moneda = 'GS' then
      v_cta_enviada := v_cta_enviada||'210500';
      elsif pag_cta.g_ctas.cod_modalidad = 41 and pag_cta.g_ctas.cod_moneda <> 'GS' then
      v_cta_enviada := v_cta_enviada||'215000';
      elsif pag_cta.g_ctas.cod_modalidad = 31 and pag_cta.g_ctas.cod_moneda <> 'GS' then
      v_cta_enviada := v_cta_enviada||'215500';
      end if;
      v_cta_enviada := v_Cta_enviada||substr(:old.nro_cuenta,-6);

      v_nro_operacion := '0000'||to_char(sysdate,'HH24MISS');
      v_pedido := v_nro_operacion|| -- NRO OPERACION
      'D' || -- FIJO PARA DESBLOQUEO EN CUENTA
      rpad(v_cta_enviada,20,' ')||-- NRO DE CUENTA
      rpad(pag_cta.g_ctas.cod_moneda,3,' ')|| -- CODIGO DE MONEDA
      rpad(NVL(TRIM(TO_CHAR(:OLD.MONTO,'0000000000000000')),' '),16,' '); -- SALDO DISPONIBLE
      v_pedido := rpad(v_pedido,50,' ');      
      --Envio y Respuesta de AS/400
      --v_respuesta:='00001041500000000000001035677';
      --v_ok:='S';
      v_ok := fue_env_tcp_mensajes('167.100.1.1',20300,5, v_pedido, v_respuesta);
      if v_ok = 'S' and substr(v_respuesta,11,3) = '000' then
         g_ok_procesar := 'S';
         g_cod_error := 0;    
      elsif v_ok = 'S' and substr(v_respuesta,11,3) = '999' then
         g_ok_procesar := 'S';
         g_cod_error := 0;
      else
        g_ok_procesar := 'N';
        if substr(v_respuesta,1,10) = v_nro_operacion then
           g_cod_error := substr(v_respuesta,11,3);
           raise_application_error(-20000,'AS/400 '||substr(v_respuesta,14));          
        else
           g_cod_error := 999;
           raise_application_error(-20000,'AS/400 '||v_respuesta);          
        end if;
      end if;    
      --
   END IF;   
end TB_GE_BLOQUEOS;
/

