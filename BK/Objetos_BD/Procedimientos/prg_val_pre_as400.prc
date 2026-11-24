create or replace procedure it.prg_val_pre_as400
(P_NRO_CUENTA IN GE_MOVIMIENTOS.NRO_CUENTA%TYPE
 ,P_COD_USUARIO IN VARCHAR2
 ,P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
 ,P_COD_MONEDA IN GE_MOVIMIENTOS.COD_MONEDA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_COD_TRA_PADRE IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE
 ,P_COD_TRANSACCION IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_NRO_DOCUMENTO IN GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE
 ,P_COTIZACION IN GE_MOVIMIENTOS.COTIZACION%TYPE
 ,P_COD_OFI_ORIGEN IN GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE
 ,p_cod_mod_padre  in number
 ,P_COD_MAD_PADRE IN GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE
 ,P_CONCEPTO IN GE_MOVIMIENTOS.CONCEPTO%TYPE
 ,P_NRO_SECUENCIA IN  GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
 ,P_MTO_EQU_LOCAL IN GE_MOVIMIENTOS.MTO_EQU_LOCAL%TYPE DEFAULT NULL
 ,P_REFERENCIA  IN VARCHAR2 DEFAULT NULL
 )  is
v_ok     varchar2(1);
v_pedido varchar2(400);
v_respuesta varchar2(4000);
v_nro_operacion varchar2(10);
v_cta_enviada varchar2(20);
g_ok_procesar varchar2(1) := 'N';
v_cod_transaccion number(4);
g_cod_error number(5) := 0;
v_referencia varchar2(40) := '';
v_tipo varchar2(1);
begin
    --- consulta cuenta y envia mensaje de verificacion de Liquidaciones de Prestamos en as/400
    pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
    begin
       select tipo into v_tipo
        from ge_transacciones
       where cod_modalidad = pag_cta.G_CTAS.cod_modalidad
         and cod_transaccion = p_cod_transaccion;
    exception
       when others then
           raise_application_error(-20000, 'Transaccion '||p_cod_transaccion||' debe ser de debito o credito');
    end;
    if pag_cta.g_ctas.cod_modalidad in (31,41) and p_cod_transaccion  in (5503,6602) then
      -- agregado para actualizar la as/400
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
      v_cta_enviada := v_Cta_enviada||substr(p_nro_cuenta,-6);

      v_nro_operacion  := '0000'||to_char(sysdate,'HH24MISS');
      v_pedido := v_nro_operacion||   -- NRO OPERACION
              'C' || -- FIJO PARA INDICAR LA CONFIRMACION
              TRIM(TO_CHAR(p_COD_MAD_PADRE,'000'))||SUBSTR(TRIM(TO_CHAR(p_cod_tra_padre,'0000')),2,3)||
              RPAD(p_COD_USUARIO,10,' ')|| -- USUARIO
              -- Se agrega el Nro. de Secuencia
              p_hora||TRIM(TO_CHAR(p_NRO_SECUENCIA,'000'))||
              TRIM(TO_CHAR(p_COD_OFI_ORIGEN,'000'))||
              RPAD(v_cta_enviada,20,' ')||
              v_tipo||
              LPAD(nvl(p_NRO_DOCUMENTO,0),20,'0')||
              RPAD(p_COD_MONEDA,3,' ')||
              TRIM(TO_CHAR(p_MONTO,'0000000000000.00'))||
              rpad(NVL(trim(to_char(p_cotizacion,'00000000000.0000')),' '),16,' ')||
              rpad(NVL(TRIM(TO_CHAR(p_MTO_EQU_LOCAL,'0000000000000000')),' '),16,' ')||
              rpad(nvl(p_concepto,' '),60,' ')||
              rpad(p_referencia,40,' ');
      v_pedido := rpad(v_pedido,300,' ');
      --v_pedido := '1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890   ';
      v_ok := fue_env_tcp_mensajes('167.100.1.1',20300,3, v_pedido, v_respuesta);

      if v_ok = 'S' and substr(v_respuesta,11,3) = '000' then
         g_ok_procesar := 'S';
         g_cod_error := 0;
      elsif v_ok = 'S' and substr(v_respuesta,11,3) = '999' and
            substr(v_respuesta,14,27) = 'CLAVE DE REGISTRO DUPLICADA' then
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
    end if;
     -- agregado por as/400
end;
/

