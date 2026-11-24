create or replace procedure it.prc_gen_arc_che_gerencia is
  cursor c_chequeras_ger is
  select c.cod_oficina, a.nro_cuenta, c.denominacion, c.cod_moneda, a.serie, a.nro_che_inicial, a.nro_che_final,
         a.fec_solicitud, fue_obt_des_refcodes('EST_CHEQUERA', a.estado) est_chequera, a.ult_che_emitido,
         pac_che.FU_OBT_CAN_EST_CHE('E', a.est_cheques) entregado, pac_che.FU_OBT_CAN_EST_CHE('G', a.est_cheques) gerencia,
         pac_che.FU_OBT_CAN_EST_CHE('P', a.est_cheques) pagados, pac_che.FU_OBT_CAN_EST_CHE('A', a.est_cheques) anulados,
         pac_che.FU_OBT_CAN_EST_CHE('O', a.est_cheques) orden_no_pago, a.est_cheques
    from it.cc_chequeras a, it.ge_cuentas c
   where a.nro_cuenta = c.nro_cuenta
     and c.cod_modalidad = 43; /*Cheques de Gerencia*/

   ---Variables del cursor
   v_cod_oficina ba_oficinas.cod_oficina%type;
   v_nro_cuenta ge_cuentas.nro_cuenta%type;
   v_denominacion ge_cuentas.denominacion%type;
   v_cod_moneda ba_monedas.cod_moneda%type;
   v_serie cc_chequeras.serie%type;
   v_nro_che_inicial cc_chequeras.nro_che_inicial%type;
   v_nro_che_final cc_chequeras.nro_che_final%type;
   v_fec_solicitud cc_chequeras.fec_cam_estado%type;
   v_est_chequera ba_cod_referencias.abreviatura%type;
   v_ult_che_emitido cc_chequeras.ult_che_emitido%type;
   v_cant_entregado number(10);
   v_cant_gerencia  number(10);
   v_cant_pagados   number(10);
   v_cant_anulados  number(10);
   v_cant_onp       number(10);
   v_est_cheques cc_chequeras.est_cheques%type;
   v_nro_che_act cc_chequeras.nro_che_inicial%type;
   v_est_cheque varchar2(20);

begin
   ---Borrar tabla temporal, para cargar con datos nuevos
   begin
    -- delete it.xx_vista_cheq_gerencia;
     commit;
   exception
     when others then
       raise_application_error(-20001, 'Error al borrar tabla temporal xx_vista_cheq_gerencia:'||sqlerrm);
   end;
   IF c_chequeras_ger%ISOPEN THEN
      CLOSE c_chequeras_ger;
   END IF;
   OPEN c_chequeras_ger;
   LOOP
     FETCH c_chequeras_ger INTO v_cod_oficina, v_nro_cuenta, v_denominacion, v_cod_moneda, v_serie, v_nro_che_inicial,
           v_nro_che_final, v_fec_solicitud, v_est_chequera, v_ult_che_emitido, v_cant_entregado, v_cant_gerencia,
           v_cant_pagados, v_cant_anulados, v_cant_onp, v_est_cheques;
     EXIT WHEN c_chequeras_ger%notfound;
     ----Recorrer el estado de los cheques, para armar la tabla temporal
     v_nro_che_act := v_nro_che_inicial;
     for i in 1..length(v_est_cheques) loop
        case
          when pac_che.FU_OBT_EST_CHEQUE(v_nro_cuenta, v_nro_che_act) = 'Entregado' then
             v_est_cheque := 'Stock';
          when pac_che.FU_OBT_EST_CHEQUE(v_nro_cuenta, v_nro_che_act) = 'Gerencia' then
             v_est_cheque := 'Emitido';
          else
             v_est_cheque := pac_che.FU_OBT_EST_CHEQUE(v_nro_cuenta, v_nro_che_act);
        end case;
        ---guardar en una variable el nro_cheque_inicial de la chequera
      /*  insert into it.xx_vista_cheq_gerencia(cod_oficina, nro_cuenta, denominacion, cod_moneda, serie,
           nro_che_inicial, nro_che_final, fec_solicitud, est_chequera, ult_che_emitido, cant_entregado,
           cant_gerencia, cant_pagados, cant_anulados, cant_onp, est_cheques, nro_cheque, est_cheque)
         values(v_cod_oficina, v_nro_cuenta, v_denominacion, v_cod_moneda, v_serie,
           v_nro_che_inicial, v_nro_che_final, v_fec_solicitud, v_est_chequera, v_ult_che_emitido, v_cant_entregado,
           v_cant_gerencia, v_cant_pagados, v_cant_anulados, v_cant_onp, v_est_cheques, v_nro_che_act, v_est_cheque);
*/
        v_nro_che_act := nvl(v_nro_che_act,0) + 1;
     end loop;
   END LOOP;
   IF c_chequeras_ger%rowcount = 0 THEN
      CLOSE c_chequeras_ger;
   END IF;
   IF c_chequeras_ger%isopen THEN
      CLOSE c_chequeras_ger;
   END IF;
   commit;
exception
   when others then
      raise_application_error(-20000, 'Error al ejecutar procedimiento: '||sqlerrm);
end;
/

