CREATE OR REPLACE PROCEDURE IT.PRH_CAL_AUMENTO
 (P_COD_EPR_DESDE IN RH_AUMENTOS.COD_EMPRESA%TYPE
 ,P_COD_EPR_HASTA IN RH_AUMENTOS.COD_EMPRESA%TYPE
 ,P_COD_CEN_COSTO IN RH_AUMENTOS.COD_CEN_COSTO%TYPE
 ,P_COD_EMP_DESDE IN RH_AUMENTOS.COD_PER_DESDE%TYPE
 ,P_COD_EMP_HASTA IN RH_AUMENTOS.COD_PER_HASTA%TYPE
 ,P_FEC_AUMENTO IN RH_AUMENTOS.FECHA%TYPE
 )
 IS
   V_ERROR        VARCHAR2(4000);
   r_emr          rh_par_empresas%rowtype;
   r_pst          rh_puestos%rowtype;
   r_ing          rh_ingresos%rowtype;
   v_dif_meses    number(5);
   v_fec_actual   date := fue_obt_fec_calendar(1);
/* Recupera el salario mínimo. */
PROCEDURE LP_OBT_SAL_MINIMO
 (P_COD_SAL_MINIMO IN RH_SAL_MINIMOS.COD_SAL_MINIMO%TYPE
 ,RP_SALMIN IN OUT RH_SAL_MINIMOS%ROWTYPE
 );

PROCEDURE LP_INS_DESCUENTOS
 (RP_DESC IN RH_DESCUENTOS%ROWTYPE
 );
FUNCTION LF_OBT_MAX_FEC_LIQ
 (P_COD_EMPLEADO IN RH_SOBRES.COD_PERSONA%TYPE
 ) RETURN DATE;
   ---
   r_aum                rh_aumentos%rowtype;
   r_salmin             rh_sal_minimos%rowtype;
   v_aumento            rh_empleados.sal_base%type;
   v_dif_aumento        rh_empleados.sal_base%type;
   v_cod_empresa        rh_empleados.cod_per_empresa%type;
   v_existe             BOOLEAN;
   r_des                rh_descuentos%rowtype;
   v_cod_des_aumento    rh_tip_descuentos.cod_tip_descuento%type;
   v_ind_apo_caja       rh_par_empresas.ind_apo_ips_caja%type;
   --- Cursor de aumentos
   CURSOR c_aumentos IS
      select *
      from rh_aumentos
      where cod_empresa >= p_cod_epr_desde
      and  cod_empresa  <= p_cod_epr_hasta
      and cod_per_desde = p_cod_emp_desde
      and cod_per_hasta = p_cod_emp_hasta
      and fecha   = p_fec_aumento
      and ind_procesado = 'N'
      and ind_afectacion = 'A'
      and cod_per_autorizador IS NOT NULL;
   --- Cursor de empleados
   CURSOR c_empleados IS
      select cod_per_empresa, cod_sal_minimo, cod_persona,
             sal_base, cod_moneda, nro_caja,
             cod_cat_empleado, cod_cen_costo, cargo, cod_oficina
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
PROCEDURE LP_INS_DESCUENTOS
 (RP_DESC IN RH_DESCUENTOS%ROWTYPE
 )
 IS
v_numero  rh_descuentos.numero%type;
BEGIN
   select nvl(max(numero),0) + 1
   into v_numero
   from rh_descuentos
   where cod_persona = rp_desc.cod_persona;
   insert into rh_descuentos
      (cod_persona, numero, fecha,
       cod_tip_descuento, ind_procesado, monto,
       cod_moneda, porcentaje, ind_automatico)
   values
      (rp_desc.cod_persona, v_numero, rp_desc.fecha,
       rp_desc.cod_tip_descuento, rp_desc.ind_procesado, rp_desc.monto,
       rp_desc.cod_moneda, rp_desc.porcentaje, rp_desc.ind_automatico);
exception
   when others then
      raise_application_error(-20000,
      'Ins.Desc.Emp. '||rp_desc.cod_persona||' '||sqlerrm);
END;
/* Recuperar fecha maxima de liquidacion */
FUNCTION LF_OBT_MAX_FEC_LIQ
 (P_COD_EMPLEADO IN RH_SOBRES.COD_PERSONA%TYPE
 )
 RETURN DATE
 IS
v_fec_liquidacion rh_sobres.fec_calculo%type;
BEGIN
   select max(s.fec_calculo)
     into v_fec_liquidacion
     from rh_sobres s
    where s.cod_persona  = p_cod_empleado
      and s.fec_calculo <= r_emr.fec_ult_cierre
      and exists (select 1
                  from   rh_liq_sueldos l
                  where  l.nro_sobre = s.nro_sobre
                  and    l.cod_tip_ingreso = r_emr.cod_tip_ing_sueldo); --- por si es una liquidacion ya existe sobre
   return v_fec_liquidacion;
exception
   when no_data_found then
      return v_fec_liquidacion;
END;
---
BEGIN
   v_existe := FALSE;
   FOR r_aum IN c_aumentos LOOP
      v_existe := TRUE;
      v_cod_empresa := r_aum.cod_empresa;
      prh_obt_empresa(v_cod_empresa, r_emr);
      ---
      if to_number(to_char(r_emr.fec_ult_cierre,'YYYYMM')) > to_number(to_char(p_fec_aumento,'YYYYMM')) then
         if nvl(r_aum.cod_tip_ingreso,0) <> nvl(r_emr.cod_tip_ing_aumento,1) then
            raise_application_error(-20000,
            'El tipo de ingreso no corresponde a Aumento Retroactivo');
         end if;
         -- Desactivar el trigger de insecion de puestos
         sql_util.ejecute_dml('alter trigger TB_RH_PUESTOS disable ', v_error);
         if v_error is not null then
            raise_application_error(-20000,
            'Disable TA_RH_EMPLEADOS '||v_error);
         end if;
         sql_util.ejecute_dml('alter trigger TA_RH_EMPLEADOS disable ', v_error);
         if v_error is not null then
            raise_application_error(-20000,
            'Disable TA_RH_EMPLEADOS '||v_error);
         end if;
      end if;
      ---
      FOR r_emp IN c_empleados LOOP
         if r_aum.monto is not null then
            v_aumento := r_emp.sal_base + r_aum.monto;
         else
            lp_obt_sal_minimo(r_emp.cod_sal_minimo, r_salmin);
            v_aumento := round((r_salmin.monto * r_aum.porcentaje)/100);
            --- agregado el 12/abr/07
            --- no sumaba el aumento
            v_aumento := r_emp.sal_base + v_aumento;
            --- fin actualizacion
         end if;
         update rh_empleados
         set sal_base = v_aumento
         where cod_persona = r_emp.cod_persona;
         ---
         v_dif_aumento    := v_aumento - r_emp.sal_base;
         ---
         if to_number(to_char(r_emr.fec_ult_cierre,'YYYYMM')) > to_number(to_char(p_fec_aumento,'YYYYMM')) then
            --- Actualizar puesto anterior
            update rh_puestos
            set    fec_hasta   = p_fec_aumento - 1
            where  cod_persona = r_emp.cod_persona
            and    fec_hasta is null;
            --- Insertar puesto nuevo
            r_pst.cod_persona       := r_emp.cod_persona;
            r_pst.fec_desde         := p_fec_aumento;
            r_pst.cod_cat_empleado  := r_emp.cod_cat_empleado;
            r_pst.cod_cen_costo     := r_emp.cod_cen_costo;
            r_pst.cargo             := r_emp.cargo;
            r_pst.salario           := v_aumento;
            r_pst.cod_moneda        := r_emp.cod_moneda;
            r_pst.cod_oficina       := r_emp.cod_oficina;
            prh_ins_puesto(r_pst);
            --- Insertar ingreso retroactivo
            --- La diferencia del aumento se multiplica por la cantidad de meses retroactivos
            v_dif_meses := ceil(months_between(r_emr.fec_ult_cierre, p_fec_aumento));
            r_ing.cod_persona         := r_emp.cod_persona;
            r_ing.fecha               := add_months(LF_OBT_MAX_FEC_LIQ(r_emp.cod_persona),1);
            r_ing.cod_tip_ingreso     := r_aum.cod_tip_ingreso;
            r_ing.monto               := nvl(v_dif_aumento,0) * nvl(v_dif_meses,0);
            r_ing.ind_procesado       := 'N';
            r_ing.cod_per_autorizador := r_aum.cod_per_autorizador;
            r_ing.cod_moneda          := r_emp.cod_moneda;
            if nvl(r_ing.monto,0) > 0 then
               prh_ins_ingreso(r_ing);
            end if;
         end if;
         --- Insertar descuento del empleado para la Caja
         select p.cod_tip_des_aumento, p.ind_apo_ips_caja
         into   v_cod_des_aumento, v_ind_apo_caja
         from   rh_par_empresas p
         where  p.cod_empresa = r_emp.cod_per_empresa;
         If (v_ind_apo_caja = 'C' or
            (v_ind_apo_caja = 'A' and r_emp.nro_caja is not null) ) then
             r_des.cod_persona       := r_emp.cod_persona;
             r_des.fecha             := add_months(LF_OBT_MAX_FEC_LIQ(r_emp.cod_persona),1);
             r_des.cod_tip_descuento := substr(v_cod_des_aumento,1,35);
             r_des.ind_procesado     := 'N';
             r_des.monto             := v_dif_aumento;
             r_des.cod_moneda        := r_emp.cod_moneda;
             r_des.porcentaje        := null;
             r_des.ind_automatico    := 'S';
             lp_ins_descuentos(r_des);
         end if;
      END LOOP;
      if to_number(to_char(r_emr.fec_ult_cierre,'YYYYMM')) > to_number(to_char(p_fec_aumento,'YYYYMM')) then
         -- Activar el trigger de insecion de puestos
         sql_util.ejecute_dml('alter trigger TB_RH_PUESTOS enable', v_error);
         if v_error is not null then
            raise_application_error(-20000,
            'Enable TA_RH_EMPLEADOS '||v_error);
         end if;
         sql_util.ejecute_dml('alter trigger TA_RH_EMPLEADOS enable', v_error);
         if v_error is not null then
            raise_application_error(-20000,
            'Enable TA_RH_EMPLEADOS '||v_error);
         end if;
      end if;
      update rh_aumentos
      set ind_procesado = 'S'
      where cod_empresa = r_aum.cod_empresa
      and cod_cen_costo = r_aum.cod_cen_costo
      and cod_per_desde = r_aum.cod_per_desde
      and cod_per_hasta = r_aum.cod_per_hasta
      and fecha   = r_aum.fecha;
      IF sql%notfound then
         raise_application_error(-20000,
         'Aumento no registrado');
      END IF;
   END LOOP;
   IF not v_existe THEN
      raise_application_error(-20000,
     'Aumento no registrado o no autorizado');
   END IF;
END;
/

