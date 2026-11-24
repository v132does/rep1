CREATE OR REPLACE PROCEDURE IT.PRH_CAL_GRATIFICAR
 (P_COD_EPR_DESDE IN RH_AUMENTOS.COD_EMPRESA%TYPE
 ,P_COD_EPR_HASTA IN RH_AUMENTOS.COD_EMPRESA%TYPE
 ,P_COD_CEN_COSTO IN RH_AUMENTOS.COD_CEN_COSTO%TYPE
 ,P_COD_EMP_DESDE IN RH_AUMENTOS.COD_PER_DESDE%TYPE
 ,P_COD_EMP_HASTA IN RH_AUMENTOS.COD_PER_HASTA%TYPE
 ,P_FEC_AUMENTO IN RH_AUMENTOS.FECHA%TYPE
 )
 IS
   v_nro_sobre      rh_sobres.nro_sobre%type;
   r_emr            rh_par_empresas%rowtype;
   r_liq            rh_liq_sueldos%rowtype;
   r_tip_ing        rh_tip_ingresos%rowtype;
   r_sob            rh_sobres%rowtype;
/* Recupera el salario mínimo. */
PROCEDURE LP_OBT_SAL_MINIMO
 (P_COD_SAL_MINIMO IN RH_SAL_MINIMOS.COD_SAL_MINIMO%TYPE
 ,RP_SALMIN IN OUT RH_SAL_MINIMOS%ROWTYPE
 );
   r_aum          rh_aumentos%rowtype;
   r_ing          rh_ingresos%rowtype;
   r_salmin       rh_sal_minimos%rowtype;
   v_aumento      rh_empleados.sal_base%type;
   v_cod_empresa  rh_empleados.cod_per_empresa%type;
   v_existe       BOOLEAN;
   --- Cursor de aumentos
   CURSOR c_aumentos IS
      select *
      from rh_aumentos
      where cod_empresa >= p_cod_epr_desde
      and  cod_empresa  <= p_cod_epr_hasta
      and cod_per_desde = p_cod_emp_desde
      and cod_per_hasta = p_cod_emp_hasta
      and fecha         = p_fec_aumento
      and ind_procesado = 'N'
      and ind_afectacion = 'G'
      and cod_per_autorizador IS NOT NULL;
   --- Cursor de empleados
   CURSOR c_empleados IS
      select cod_per_empresa, cod_sal_minimo, cod_persona, tipo,
             sal_base, cod_cen_costo, cod_moneda
      from   rh_empleados
      where  cod_per_empresa = v_cod_empresa
      and    cod_persona >= p_cod_emp_desde
      and    cod_persona <= p_cod_emp_hasta
      and    fec_egreso is null
      and    cod_cen_costo = nvl(p_cod_cen_costo,cod_cen_costo);
/* Recupera el salario mínimo. */
PROCEDURE LP_OBT_SAL_MINIMO
 (P_COD_SAL_MINIMO IN RH_SAL_MINIMOS.COD_SAL_MINIMO%TYPE
 ,RP_SALMIN IN OUT RH_SAL_MINIMOS%ROWTYPE
 )
 IS
BEGIN
   select *
   into rp_salmin
   from rh_sal_minimos
   where cod_sal_minimo = p_cod_sal_minimo;
exception
    when no_data_found then
       raise_application_error(-20000,
       'Salario minimo '||to_char(p_cod_sal_minimo)||' no registrado');
END;
BEGIN
   v_existe := FALSE;
   FOR r_aum IN c_aumentos LOOP
      v_existe := TRUE;
      v_cod_empresa := r_aum.cod_empresa;
      FOR r_emp IN c_empleados LOOP
         if r_aum.monto is not null then
            v_aumento := r_aum.monto;
         else
           if fug_obt_tip_implementacion = 1 then
              v_aumento := round((r_emp.sal_base * r_aum.porcentaje / 100),0);
           else
              lp_obt_sal_minimo(r_emp.cod_sal_minimo, r_salmin);
              v_aumento := round((r_salmin.monto * r_aum.porcentaje / 100),0);
           end if;
           ---
         end if;
         /*
         Se genera un sobre por separado para Bco. Regional
         */
         if fug_obt_tip_implementacion = 1 then
            if nvl(v_aumento,0) > 0 then
               prh_obt_empresa(r_emp.cod_per_empresa, r_emr);
               --- Insertar liquidacion de aguinaldo
               r_liq.cod_persona   := r_emp.cod_persona;
               r_liq.cod_cen_costo := r_emp.cod_cen_costo;
               r_liq.vac_fec_desde := null;
               r_liq.ing_numero    := null;
               r_liq.hex_fec_hor_extra := null;
               r_liq.des_numero    := null;
               --- Recuperar tipo de mvto del ingreso
               prh_obt_tip_ingreso(r_emr.cod_tip_ing_gratificacion, r_tip_ing);
               r_liq.cod_tip_ingreso := r_emr.cod_tip_ing_gratificacion;
               r_liq.cod_transaccion := r_tip_ing.cod_transaccion;
               r_liq.cod_modulo      := r_tip_ing.cod_modulo;
               r_liq.cod_modalidad   := r_tip_ing.cod_modalidad;
               r_liq.monto           := nvl(v_aumento,0);
               r_liq.computable      := null;
               r_liq.cod_moneda      := r_emp.cod_moneda;
               IF nvl(r_liq.monto,0) > 0 THEN
                  r_sob.cod_persona  := r_emp.cod_persona;
                  r_sob.ano          := to_number(to_char(p_fec_aumento,'YYYY'));
                  r_sob.mes          := to_number(to_char(p_fec_aumento,'MM'));
                  if to_number(to_char(p_fec_aumento,'DD')) > 15 then
                     r_sob.quincena  := 2;
                  else
                     r_sob.quincena  := 1;
                  end if;
                  if r_emp.tipo = 'Z' and r_emr.cod_empresa <> '01' then
                     r_sob.nro_patronal := r_emr.pat_ips_02;
                  else
                     r_sob.nro_patronal := r_emr.pat_ips_01;
                  end if;
                  r_sob.fec_calculo  := p_fec_aumento;
                  prh_ins_sobre(r_sob, v_nro_sobre);
                  r_liq.nro_sobre := v_nro_sobre;
                  prh_ins_liq_sueldo(r_liq);
               END IF;
            end if;
         else
            --- Insertar ingreso
            r_ing.cod_persona      := r_emp.cod_persona;
            r_ing.fecha            := p_fec_aumento;
            r_ing.cod_tip_ingreso  := r_aum.cod_tip_ingreso;
            r_ing.monto            := v_aumento;
            r_ing.ind_procesado    := 'N';
            r_ing.cod_per_autorizador := r_aum.cod_per_autorizador;
            --- se agrego codigo de la moneda
            r_ing.cod_moneda          := r_emp.cod_moneda;
            prh_ins_ingreso(r_ing);
         end if;
      END LOOP;
      update rh_aumentos
      set ind_procesado = 'S'
      where cod_empresa = r_aum.cod_empresa
      and cod_cen_costo = r_aum.cod_cen_costo
      and cod_per_desde = r_aum.cod_per_desde
      and cod_per_hasta = r_aum.cod_per_hasta
      and fecha         = r_aum.fecha;
      IF sql%notfound then
         raise_application_error(-20000,
         'Gratificación no registrada');
      END IF;
   END LOOP;
   IF not v_existe THEN
      raise_application_error(-20000,
     'Gratificación no registrada o no autorizada');
   END IF;
END;
/

