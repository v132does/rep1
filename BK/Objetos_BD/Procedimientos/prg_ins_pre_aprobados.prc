CREATE OR REPLACE PROCEDURE IT.PRG_INS_PRE_APROBADOS IS

   v_lote ge_pro_pre_aprobados.lote%TYPE;
   v_cod_modalidad ge_pro_pre_aprobados.cod_modalidad%TYPE;
   v_max_plazo ge_pro_pre_aprobados.max_plazo%type;
   v_msj_error varchar2(1000);
   v_60_meses  ge_pro_pre_aprobados.plz_60_meses%type;
   v_54_meses  ge_pro_pre_aprobados.plz_54_meses%type;
   v_48_meses  ge_pro_pre_aprobados.plz_48_meses%type;
   v_42_meses  ge_pro_pre_aprobados.plz_42_meses%type;
   v_36_meses  ge_pro_pre_aprobados.plz_36_meses%type;
   v_30_meses  ge_pro_pre_aprobados.plz_30_meses%type;
   v_24_meses  ge_pro_pre_aprobados.plz_24_meses%type;
   v_18_meses  ge_pro_pre_aprobados.plz_18_meses%type;
   v_12_meses  ge_pro_pre_aprobados.plz_12_meses%type;
   error_tasas exception;
   CURSOR cr_pre_apr_tmp IS
      SELECT * FROM ge_pro_pre_aprobados_tmp;

BEGIN
   ---- Requerimiento: CNFIDCCP-3.
   -- Fecha: 03/06/2015.
   PRG_VAL_PRE_APROBADOS;
   --
   prg_val_tas_rec_preaprobado(v_msj_error);
   if v_msj_error is null then
     SELECT s_pro_lote.nextval INTO v_lote FROM dual;

     FOR a IN cr_pre_apr_tmp LOOP
       begin
         Update ge_pro_pre_aprobados
            Set estado = 'C'
          Where cod_persona = a.cod_persona
            And ((cod_modulo = a.cod_modulo And cod_modalidad Is Null) --módulo 5 tarjetas
                Or (cod_modulo = a.cod_modulo And cod_modalidad = a.cod_modalidad)) --módulo 6 préstamos
            And estado = 'V';
       exception
         when others then
           raise_application_error(-20000, 'Error al actualizar estado en GE_PRO_PRE_APROBADOS' || SQLERRM);
       end;
        If a.cod_modulo = 5 Then
           v_cod_modalidad := null; --tarjetas no tiene modalidad, se puede elegir cualquiera de ellas en la solicitud
        Elsif a.cod_modulo = 6 Then
           v_cod_modalidad := a.cod_modalidad;
        End If;
        v_60_meses := a.plz_60_meses;
        v_54_meses := a.plz_54_meses;
        v_48_meses := a.plz_48_meses;
        v_42_meses := a.plz_42_meses;
        v_36_meses := a.plz_36_meses;
        v_30_meses := a.plz_30_meses;
        v_24_meses := a.plz_24_meses;
        v_18_meses := a.plz_18_meses;
        v_12_meses := a.plz_12_meses;
        --verificar max_plazo, cerar los plz_X_meses si sobrepasa el maximo
        v_max_plazo := a.max_plazo;
        if v_max_plazo < 12 then
           v_60_meses := null;
           v_54_meses := null;
           v_48_meses := null;
           v_42_meses := null;
           v_36_meses := null;
           v_30_meses := null;
           v_24_meses := null;
           v_18_meses := null;
           v_12_meses := null;
        elsif v_max_plazo < 18 then
           v_60_meses := null;
           v_54_meses := null;
           v_48_meses := null;
           v_42_meses := null;
           v_36_meses := null;
           v_30_meses := null;
           v_24_meses := null;
           v_18_meses := null;
        elsif v_max_plazo < 24 then
           v_60_meses := null;
           v_54_meses := null;
           v_48_meses := null;
           v_42_meses := null;
           v_36_meses := null;
           v_30_meses := null;
           v_24_meses := null;
        elsif v_max_plazo < 30 then
           v_60_meses := null;
           v_54_meses := null;
           v_48_meses := null;
           v_42_meses := null;
           v_36_meses := null;
           v_30_meses := null;
        elsif v_max_plazo < 36 then
           v_60_meses := null;
           v_54_meses := null;
           v_48_meses := null;
           v_42_meses := null;
           v_36_meses := null;
        elsif v_max_plazo < 42 then
           v_60_meses := null;
           v_54_meses := null;
           v_48_meses := null;
           v_42_meses := null;
        elsif v_max_plazo < 48 then
           v_60_meses := null;
           v_54_meses := null;
           v_48_meses := null;
        elsif v_max_plazo < 54 then
           v_60_meses := null;
           v_54_meses := null;
        elsif v_max_plazo < 60 then
           v_60_meses := null;
        end if;
        -- Requerimiento: CNFIDCCP-3.
        -- Fecha: 03/06/2015.
        if a.cod_modulo <> 5 then
        INSERT INTO ge_pro_pre_aprobados
           (cod_persona, lote, cod_oficina, cod_usu_oficial, lin_vigente_tc, lin_nueva_tc,
            mto_max_cuota, plz_12_meses, plz_18_meses, plz_24_meses, plz_30_meses, plz_36_meses,
            plz_42_meses, plz_48_meses, plz_54_meses, plz_60_meses, cod_segmento, val_min_tasa,
            val_max_tasa, cod_campana, cod_modulo, cod_modalidad, min_monto, max_monto, min_plazo,
            max_plazo, ind_evaluacion, nro_cta_renovada, pun_scoring, pro_mora,cod_sub_modalidad,denominacion, fec_vto_campana) -- --Requerimiento: CNFNORMA-173 PCCFPPTC-1 - 10/2016 --
        VALUES
           (a.cod_persona, v_lote, a.cod_oficina, a.cod_usu_oficial, a.lin_vigente_tc, a.lin_nueva_tc,
            a.mto_max_cuota, /*a.plz_12_meses, a.plz_18_meses, a.plz_24_meses, a.plz_30_meses, a.plz_36_meses,
            a.plz_42_meses, a.plz_48_meses, a.plz_54_meses, a.plz_60_meses,*/
            v_12_meses, v_18_meses, v_24_meses, v_30_meses, v_36_meses,
            v_42_meses, v_48_meses, v_54_meses, v_60_meses, a.cod_segmento, a.val_min_tasa,
            a.val_max_tasa, a.cod_campana, a.cod_modulo, v_cod_modalidad, a.min_monto, a.max_monto, a.min_plazo,
            a.max_plazo, a.ind_evaluacion, a.nro_cta_renovada,a.pun_scoring, a.pro_mora, a.cod_sub_modalidad,a.denominacion, a.fec_vto_campana); -- --Requerimiento: CNFNORMA-173 PCCFPPTC-1 - 10/2016 --
        else
            if a.lin_nueva_tc is null then
                 raise_application_error(-20001, 'Lin_nueva_tc no puede ser nulo para modulo = 5');
            end if;

           INSERT INTO ge_pro_pre_aprobados
           (cod_persona, lote, cod_oficina, cod_usu_oficial, lin_vigente_tc, lin_nueva_tc,
            mto_max_cuota, plz_12_meses, plz_18_meses, plz_24_meses, plz_30_meses, plz_36_meses,
            plz_42_meses, plz_48_meses, plz_54_meses, plz_60_meses, cod_segmento, val_min_tasa,
            val_max_tasa, cod_campana, cod_modulo, cod_modalidad, min_monto, max_monto, min_plazo,
            max_plazo, ind_evaluacion, nro_cta_renovada, pun_scoring, pro_mora, denominacion, fec_vto_campana)--Requerimiento: CNFNORMA-173
        VALUES
           (a.cod_persona, v_lote, a.cod_oficina, a.cod_usu_oficial, a.lin_vigente_tc, a.lin_nueva_tc,
            a.mto_max_cuota, /*a.plz_12_meses, a.plz_18_meses, a.plz_24_meses, a.plz_30_meses, a.plz_36_meses,
            a.plz_42_meses, a.plz_48_meses, a.plz_54_meses, a.plz_60_meses,*/
            v_12_meses, v_18_meses, v_24_meses, v_30_meses, v_36_meses,
            v_42_meses, v_48_meses, v_54_meses, v_60_meses, a.cod_segmento, a.val_min_tasa,
            a.val_max_tasa, a.cod_campana, a.cod_modulo, v_cod_modalidad, a.min_monto, a.lin_nueva_tc/*a.max_monto*/, a.min_plazo,
            a.max_plazo, a.ind_evaluacion, a.nro_cta_renovada,a.pun_scoring, a.pro_mora,a.denominacion, a.fec_vto_campana);--Requerimiento: CNFNORMA-173
        end if;
     END LOOP;
   else
     raise error_tasas;
   end if;
EXCEPTION
   WHEN dup_val_on_index THEN
      raise_application_error(-20000, 'Registro Duplicado en Archivo.');
   WHEN error_tasas THEN
     raise_application_error(-20000, v_msj_error);
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error en prg_ins_pre_aprobados. ' || SQLERRM);
END;
/

