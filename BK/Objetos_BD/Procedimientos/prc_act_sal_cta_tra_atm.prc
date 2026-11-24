create or replace procedure it.prc_act_sal_cta_tra_atm is

--DE-2209 - Optimizar proceso FUJ_PRO_TRA_ATM - DYD-SDSL-3300 - Junio/2016
--Propósito: Actualizar saldo de Cuentas Transaccionales que tuvieron movimientos, tomamos el monto total
--de los movimientos de Crédito que fueron efectuados vía ATM agrupados por cuenta/moneda

--Declaración Variables--
  v_nro_cuenta       ge_cuentas.nro_cuenta%type;
  v_fec_proceso      date := pag_cal.FU_OBT_FEC_ACTUAL(3);
  v_can_registros    number;
  v_det_error        varchar2(200);


--Cursor Principal de los Mov. ATM de Cta Transaccional--
Cursor cur_mov_ctas is
  SELECT A.COD_MODULO, A.COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA,
         MAX(TO_CHAR(A.FEC_INSERCION,'HH24:MI:SS')) HORA,
         SUM(decode(B.TIPO,'D',1,0)) can_debito,
         SUM(decode(B.TIPO,'D',nvl(MONTO,0),0)) mto_debito,
         SUM(decode(B.TIPO,'C',1,0)) can_credito,
         SUM(decode(B.TIPO,'C',nvl(MONTO,0),0)) mto_credito
    FROM GE_MOVIMIENTOS A, GE_TRANSACCIONES B
        WHERE A.COD_TRANSACCION > 0
          AND ESTADO = 'N'
          AND NRO_CUENTA IS NOT NULL
          AND A.COD_USUARIO LIKE 'ATM%'
          AND EXISTS (select 1
                        from cc_cta_transaccionales
                       where nro_cuenta = a.nro_cuenta
                         and (activo = 'S' or (activo = 'N' and fec_inactivacion > v_fec_proceso))
                         and fec_activacion <= v_fec_proceso)
          AND B.COD_TRANSACCION = A.COD_TRANSACCION
          AND B.COD_MODULO = A.COD_MODULO
          AND B.COD_MODALIDAD = A.COD_MODALIDAD
    GROUP BY A.COD_MODULO, A.COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA;

Cursor cur_sal_ctas is
   select x.*
     from ge_log_sal_atm x
    where x.fecha = v_fec_proceso
      and tip_cuenta = 'CT';

---Declaración de procedimientos internos
PROCEDURE lp_tra_env_email IS

v_para         VARCHAR2(4000);
v_asunto       VARCHAR2(2000);
v_titulo       VARCHAR2(2000);
v_texto        LONG;
v_detalle      LONG;
v_hin_mail     ge_ra_log_mail.hor_inicio%type;
v_hfi_mail     ge_ra_log_mail.hor_fin%type;
v_det_error    ge_ra_log_mail.det_error%type;

Cursor cur_sal_noact is
   select x.*, c.denominacion
     from ge_log_sal_atm x, cc_cta_corrientes c
    where x.nro_cuenta = c.nro_cuenta
      and x.cod_modulo = c.cod_modulo
      and x.cod_modalidad = c.cod_modalidad
      and x.fecha = v_fec_proceso
      and x.actualizado = 'N'
      and x.tip_cuenta = 'CT';

BEGIN

 v_asunto   := 'Saldos No Actualizados en Cuentas Transaccionales (11-159-prg_act_sal_pen_atm): fecha '||to_char(v_fec_proceso, 'DD/MM/YYYY');

 v_titulo := 'Nro. Cuenta '||chr(09)||
             'Denominación'||chr(09)||
             'Moneda'||chr(09)||
             'Mto. Débito'||chr(09)||
             'Mto. Crédito'||chr(09)||
             'Cant. Débito'||chr(09)||
             'Cant. Crédito'||chr(09)||
             'Fecha'||chr(09)||
             'Det. Error'||chr(10);

 for c in cur_sal_noact loop

     v_texto := c.nro_cuenta||chr(09)||
                c.denominacion||chr(09)||
                c.cod_moneda||chr(09)||
                c.mto_debito||chr(09)||
                c.mto_credito||chr(09)||
                c.can_debito||chr(09)||
                c.can_credito||chr(09)||
                to_char(v_fec_proceso, 'DD/MM/YYYY')||chr(09)||
                c.det_error||chr(10);

 END LOOP;
  If v_texto is not null then
     BEGIN
         v_hin_mail := to_char(sysdate, 'hh24:mi:ss');

         v_para := fug_obt_pardinamico('ENV_EMA_ACT_SAL_ATM');
         v_detalle :=  v_titulo||v_texto;

         it_mail.mail(fug_obt_dir_correo,
                      v_para,
                      v_asunto,
                      v_detalle);

         v_hfi_mail := to_char(sysdate, 'hh24:mi:ss');

     EXCEPTION
        when others then
           v_det_error := substr(sqlerrm, 1, 4000);
           INSERT INTO ge_ra_log_mail (fec_envio,
                                       nom_archivo,
                                       dir_correo,
                                       mensaje,
                                       det_error,
                                       hor_inicio,
                                       hor_fin)
                               VALUES (SYSDATE,
                                       null,
                                       v_para,
                                       v_asunto,
                                       v_det_error,
                                       v_hin_mail,
                                       v_hfi_mail);

    END;
 End if;

END lp_tra_env_email;


begin
  --Verificacion de registros--
      select nvl(count(*),0)
        into v_can_registros
        from ge_log_sal_atm x
        where x.fecha = v_fec_proceso
          and x.tip_cuenta = 'CT';

      if nvl(v_can_registros,0) > 0 then
         raise_application_error(-20005,'Error. Ya actualizados saldos de ATM de fecha '||TO_CHAR(V_FEC_PROCESO,'DD/MM/YYYY'));
      end if;

      --Insertar Registros a Actualizar--
      for mov in cur_mov_ctas loop
          insert into ge_log_sal_atm
          (fecha, cod_modulo, cod_modalidad, cod_oficina,
           nro_cuenta, cod_moneda, hora, can_debito,
           mto_debito, can_credito, mto_credito, actualizado, tip_cuenta)
           values
          (v_fec_proceso, mov.cod_modulo, mov.cod_modalidad, mov.cod_oficina,
           mov.nro_cuenta, mov.cod_moneda, mov.hora, mov.can_debito,
           mov.mto_debito, mov.can_credito, mov.mto_credito, 'N', 'CT');
      end loop;
      commit;

      --Proceso Principal--
      for sal in cur_sal_ctas loop
          v_nro_cuenta := sal.nro_cuenta;
          IF PAG_CTA.FU_LLAVEAR_CUENTA(sal.cod_modalidad, v_nro_cuenta, 'N') = 'N' Then
             --Si no puede bloquear pasa a la siguiente cuenta sin actualizar--
             update ge_log_sal_atm b
                set b.det_error = 'No se puede realizar bloqueo de la cuenta: '||v_nro_cuenta
             where b.nro_cuenta = v_nro_cuenta
               and b.tip_cuenta = 'CT';
             commit;
          else

            begin
                update cc_cta_corrientes a
                   set sal_total = nvl(sal_total, 0) + nvl(sal.mto_credito,0) - nvl(sal.mto_debito,0),
                       estado = decode(estado, 'I', 'N', estado),
                       fec_ult_movimiento = v_fec_proceso,
                       hor_ult_movimiento = sal.hora
                 where nro_cuenta = v_nro_cuenta;

            exception
              when others then
                 v_det_error := 'No se puede actualiza saldo de la cuenta: '||v_nro_cuenta|| sqlerrm;
                 --Si no puede actualizar saldo de la cuenta por otro motivo que no sea bloqueo.
                 update ge_log_sal_atm b
                    set b.det_error = v_det_error
                 where b.nro_cuenta = v_nro_cuenta
                   and b.tip_cuenta = 'CT';
                 commit;
             end;

             --Se actualiza indicador de actualizado si no ocurre ningún error en actualización de saldo
             update ge_log_sal_atm b
                set b.actualizado = 'S'
              where b.nro_cuenta = v_nro_cuenta
                and b.tip_cuenta = 'CT';
             commit;
          end if;
      end loop;

      --Elimina Registros de Tabla de logs no utilizados--
      delete from ge_log_sal_atm x
       where x.fecha < (v_fec_proceso -5)
         and x.actualizado = 'S'
         and x.tip_cuenta = 'CT';


    --Agregar envio de emails a EP / OPERACIONES por Saldos No Actualizadps--
    lp_tra_env_email;
exception
  when others then
       raise_application_error(-20005,'Error en prg_act_sal_pen_atm:'||sqlerrm);
end;
/

