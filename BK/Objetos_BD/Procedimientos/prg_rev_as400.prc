CREATE OR REPLACE PROCEDURE IT.PRG_REV_AS400
 (P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
 ,P_COD_USUARIO IN GE_MOVIMIENTOS.COD_USUARIO%TYPE
 ,P_COD_USU_REVERSION IN GE_MOVIMIENTOS.COD_USU_REVERSION%TYPE default user
 ,P_HOR_REVERSION IN GE_MOVIMIENTOS.HOR_REVERSION%TYPE default to_char(sysdate,'HH24:MI:SS')
 ,P_ES_NOCTURNO IN VARCHAR2 default 'N'
 ,P_CONCEPTO    IN VARCHAR2 default null
 )
 IS
-- solo para conexion con la as/400
v_ok     varchar2(1);
v_pedido varchar2(400) := null;
v_respuesta varchar2(4000);
v_nro_operacion varchar2(10);
v_cta_enviada varchar2(20);
v_tipo varchar2(1);

CURSOR CUR_GMOVI IS
    SELECT FECHA,HORA,COD_USUARIO,NRO_SECUENCIA,FEC_VALOR,MONTO,NRO_CUENTA,COD_MONEDA,
           COD_OFICINA,COD_ERROR,COD_RETENCION,FEC_FIN_RETENCION,EST_CUENTA,ESTADO,COD_CAUSA,
           COD_BANCO,COD_OFI_ORIGEN,CONCEPTO,COD_TASA,VAL_TASA,COD_RUBRO,COD_REF_CAMBIO,REVERSADO,
           COD_USU_REVERSION,HOR_REVERSION,EMI_AVISO,COD_TRA_PADRE,COD_MOD_PADRE,COD_MAD_PADRE,
           COD_TRANSACCION,COD_MODULO,COD_MODALIDAD,MTO_EQU_LOCAL,NRO_CAJA,COTIZACION,COD_BCO_CENTRAL,
           NRO_DOCUMENTO,NRO_DOCUMENTO2,NRO_DOCUMENTO3,NRO_DOCUMENTO4,PROTEGIDO,COD_AUTORIZACION,
           COD_USU_AUTORIZADOR,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,
           TIP_MOV_RUBRO,COD_TIP_OPE_CAMBIO,REFERENCIA, COD_PERSONA, COD_SIT_CONTABLE
    FROM GE_MOVIMIENTOS
    WHERE       FECHA = P_FECHA
    AND          HORA = P_HORA
    AND   COD_USUARIO = P_COD_USUARIO
    AND REVERSADO     = 'N'
    AND COD_MODALIDAD IN (31,41)
    AND NRO_CUENTA IS NOT NULL
  -- and nro_cuenta like '%15895'
  -- and hora = '16:16:56'
    AND MONTO <> 0
    ORDER BY NRO_SECUENCIA DESC;
begin

     FOR rp_gmovi IN CUR_GMOVI LOOP

          if rp_gmovi.cod_modalidad in (31,41)  then
            begin
               select tipo into v_tipo
                 from ge_transacciones
                 where cod_modalidad = rp_gmovi.cod_modalidad
                 and cod_transaccion = rp_gmovi.cod_transaccion;
            exception
               when others then
                   raise_application_error(-20000, 'Transaccion '||rp_gmovi.cod_transaccion||' debe ser de debito o credito');
            end;
            -- agregado para actualizar la as/400
            v_cta_enviada := lpad(rp_gmovi.COD_OFICINA,2,'0');
            if rp_gmovi.cod_modalidad = 41 and rp_gmovi.cod_moneda = 'GS' then
                v_cta_enviada := v_cta_enviada||'210100';
            elsif rp_gmovi.cod_modalidad = 31 and rp_gmovi.cod_moneda = 'GS' then
                 v_cta_enviada := v_cta_enviada||'210500';
            elsif rp_gmovi.cod_modalidad = 41 and rp_gmovi.cod_moneda <> 'GS' then
                 v_cta_enviada := v_cta_enviada||'215000';
            elsif rp_gmovi.cod_modalidad = 31 and rp_gmovi.cod_moneda <> 'GS' then
                 v_cta_enviada := v_cta_enviada||'215500';
            end if;
            v_cta_enviada := v_Cta_enviada||substr(rp_gmovi.nro_cuenta,5,6);

            v_nro_operacion  := '0000'||to_char(sysdate,'HH24MISS');
            v_pedido := v_nro_operacion||   -- NRO OPERACION
                    'C' || -- FIJO PARA INDICAR LA CONFIRMACION
                    TRIM(TO_CHAR(rp_gmovi.COD_MAD_PADRE,'000'))||TRIM(TO_CHAR(rp_gmovi.cod_tra_padre,'000'))||
                    RPAD(NVL(P_COD_USU_REVERSION,USER),10,' ')|| -- USUARIO
                    -- Se agrega el Nro. de Secuencia
                    P_HOR_REVERSION||TRIM(TO_CHAR(rp_gmovi.nro_secuencia,'000'))||
                    TRIM(TO_CHAR(rp_gmovi.COD_OFI_ORIGEN,'000'))||
                    RPAD(v_cta_enviada,20,' ')||
                    v_tipo||
                    LPAD(nvl(rp_gmovi.NRO_DOCUMENTO,0),20,'0')||
                    LPAD(rp_gmovi.COD_MONEDA,3,' ')||
--                    TRIM(TO_CHAR((rp_gmovi.MONTO * -1),'0000000000000.00'))||
                    TRIM(TO_CHAR((rp_gmovi.MONTO * -1),'000000000000.00'))||
                     rpad(NVL(trim(to_char(rp_gmovi.cotizacion,'00000000000.0000')),' '),16,' ')||
                    rpad(NVL(TRIM(TO_CHAR(rp_gmovi.MTO_EQU_LOCAL,'0000000000000000')),' '),16,' ')||
                    rpad(nvl(p_concepto,' '),60,' ')||
                    rpad((rpad(nvl(rp_gmovi.cod_usuario,user),10,' ')||nvl(p_hora,to_char(sysdate,'HH24:MI:SS'))||TRIM(TO_CHAR(rp_gmovi.nro_secuencia,'000'))),40,' ');
            v_pedido := rpad(v_pedido,300,' ');

          end if;
           -- agregado por as/400
          -- as/400
          if trim(v_pedido) is not null then
              --v_pedido := '1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890   ';
              v_ok := fue_env_tcp_mensajes('167.100.1.1',20300,3, v_pedido, v_respuesta);

              if v_ok = 'S' and substr(v_respuesta,11,3) = '000' then
                 null;  -- no hay problemas, se actualiza
                 ---
              else

                 if substr(v_respuesta,1,10) = v_nro_operacion then
                    raise_application_error(-20000,'AS/400 '||substr(v_respuesta,31));
                 else
                     raise_application_error(-20000,'AS/400 '||v_respuesta);

                 end if;
              end if;

          end if;

    END LOOP;

end;
/

