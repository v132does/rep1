CREATE OR REPLACE PROCEDURE IT."PRG_BLO_DEU_PENDIENTES" (
P_NRO_CUENTA IN VARCHAR2,
MONTO IN NUMBER,
LOTE NUMBER DEFAULT 1) is
---------VARIABLES-----------------------------------------------
cursor c_deuda_pendientes is
       select * from mi_deu_pendientes mdp
        where nro_cuenta = p_nro_cuenta;

c_datos_deuda c_deuda_pendientes%rowtype;

v_saldo NUMBER(16):=0;
v_mto_bloquear NUMBER(16):=0;
v_ok     varchar2(1);
v_pedido varchar2(400) := null;
v_respuesta varchar2(4000);
v_nro_operacion varchar2(10);
v_cta_enviada varchar2(20);
v_fec_actual date:=pag_cal.FU_OBT_FEC_ACTUAL(1);
v_hora ge_bloqueos.hor_inicio%type;
g_ok_procesar varchar2(1) := 'N';
g_cod_error number(5) := 0;
v_nro_documento ba_personas.nro_documento%type;
v_est_proceso number(1) := 0;
v_intentos INTEGER:=0;

/*
 Este proceso consta de 3 estados
      1 - 0 = nueva transaccion o aun no procesodo
      2 - 1 = procesado pero falla en respuesta as400
*/
/*
  PARAMETRO LOTE
  0 = Procesar todo el ardeupend
  1 = procesar Transacciones individuales
*/
-----------------------------------------------------------------
begin
  pre_cam_for_numerico('.,');
  pag_cta.PR_OBT_CUENTA(P_NRO_CUENTA); --seteo de cuenta en IT
  --v_saldo:=pag_cta.FU_SAL_DIS_COMBINADA; --saldo Disponible en IT
  v_saldo:= nvl(pag_cta.FU_SAL_DIS_COMBINADA,0) + nvl(pag_cta.fu_obt_lin_sobregiro(P_NRO_CUENTA),0); --saldo + lin de sobregiro en IT
  if  v_saldo > 0 then
  open c_deuda_pendientes;
    loop
      fetch c_deuda_pendientes into c_datos_deuda;
        if  c_deuda_pendientes%found then
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
                  v_nro_operacion := '0000'||to_char(sysdate,'HH24MISS');
                  v_pedido := v_nro_operacion||
                  'S' ||
                  rpad(v_cta_enviada,20,' ')||
                  rpad(pag_cta.g_ctas.cod_moneda,3,' ')||
                  rpad(NVL(TRIM(TO_CHAR(v_saldo,'0000000000000000')),' '),16,' ');
                  v_pedido := rpad(v_pedido,300,' ');
                  v_est_proceso := c_datos_deuda.est_proceso;
                  WHILE v_intentos <= 3 LOOP
                      IF LOTE = 1 THEN
                         v_ok := fue_env_tcp_mensajes('167.100.1.1',20300,3, v_pedido, v_respuesta);
                      ELSE
                         IF v_est_proceso = 0 THEN
                            v_ok := fue_env_tcp_mensajes('167.100.1.1',20300,3, v_pedido, v_respuesta);
                         ELSE
                            v_ok:='N';
                            v_respuesta:='-999';
                         END IF;
                      END IF;
                      IF v_ok='N' AND v_respuesta = '02-Limite de tiempo de espera' THEN
                         v_intentos:=v_intentos + 1;
                      ELSE
                         v_intentos:=4;
                      END IF;
                  END LOOP;
                  ----
                  IF v_ok = 'S' and substr(v_respuesta,11,3) = '000' THEN
                       update simgia_ardeupend set est_proceso = 1, respuesta = v_respuesta where nro_cuenta = p_nro_cuenta;
                        g_ok_procesar := 'S';
                        g_cod_error := 0;
                        v_mto_bloquear:=to_number(substr(v_respuesta,15,16));
                        v_hora:=to_char(sysdate,'HH24:MI:SS');
                        if v_mto_bloquear > 0 then
                           pag_cta.PR_ACT_SAL_CTA(P_NRO_CUENTA,
                                                  pag_cta.g_ctas.cod_modalidad,
                                                  'C',
                                                  v_fec_actual,
                                                  v_hora,
                                                  0,
                                                  0,
                                                  v_mto_bloquear,
                                                  'N',
                                                  'N');
                                                  if pag_cta.G_COD_ERROR = 0 then
                                                     select nvl(max(nro_documento),0) + 1
                                                     into v_nro_documento
                                                     from ge_bloqueos
                                                     where nro_cuenta = p_nro_cuenta
                                                     and fec_inicio = v_fec_actual;
                                                     begin
                                                         insert into ge_bloqueos(nro_cuenta, fec_inicio, nro_documento,
                                                         cod_causa, monto, hor_inicio,
                                                         fec_fin, tipo, observacion, tip_bloqueo)
                                                         values
                                                         (P_NRO_CUENTA, v_fec_actual, v_nro_documento,--rp_gbloq.nro_documento
                                                         251, v_mto_bloquear, v_hora,
                                                         v_fec_actual, 'S', 'BLOQUEO POR DEBITO DE DEUDA PENDIENTE', 'A');
                                                     exception when others then
                                                               RAISE_APPLICATION_ERROR(-20000,'Err.Ins.Bloqueo:'||sqlerrm);
                                                     end;
                                                  end if;
                        else
                                                  update simgia_ardeupend set est_proceso = 0, respuesta = v_respuesta where nro_cuenta = p_nro_cuenta;
                        end if ;
                  ELSIF v_ok = 'S' and substr(v_respuesta,11,3) = '999' then
                    g_ok_procesar := 'S';
                    g_cod_error := 0;
                    update simgia_ardeupend set est_proceso = 9, respuesta = v_respuesta where nro_cuenta = p_nro_cuenta;
                  ELSE
                    g_ok_procesar := 'N';
                    update simgia_ardeupend set est_proceso = 9, respuesta = v_respuesta where nro_cuenta = p_nro_cuenta;

                    IF substr(v_respuesta,1,10) = v_nro_operacion then
                      g_cod_error := substr(v_respuesta,11,3);
                      raise_application_error(-20000,'AS/400 '||substr(v_respuesta,14));
                    ELSE
                      IF v_respuesta = '-999' THEN
                         g_ok_procesar := 'S';
                         g_cod_error := 0;
                      ELSE
                         g_cod_error := 999;
                         raise_application_error(-20000,'AS/400 '||v_respuesta);
                      END IF;
                    END IF;

                  END IF;
            end if;
      exit when c_deuda_pendientes%notfound;
    end loop;
  close c_deuda_pendientes;
  ELSE
        update simgia_ardeupend set est_proceso = 7, respuesta = 'No se procesa, saldo es 0' where nro_cuenta = p_nro_cuenta;
  end if;
exception when others then
     RAISE_APPLICATION_ERROR(-20000,'Error:'||SQLERRM);
end PRG_BLO_DEU_PENDIENTES;
/

