CREATE OR REPLACE FUNCTION IT.FUG_NIV_ENDEUDAMIENTO
 (P_COD_PERSONA IN VARCHAR2
 )
 RETURN NUMBER
 IS

  Result number := 0;

/* Obtener total de egresos del cliente. */
FUNCTION FL_OBT_TOT_ING_EGR
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_TIPO IN CR_CON_ING_EGR.TIPO%TYPE
 )
 RETURN NUMBER;
v_cuo_entidad    pr_cuotas.mto_capital%type;
   v_cuo_otr_fin    pr_cuotas.mto_capital%type;
   v_cuo_adminis    pr_cuotas.mto_capital%type;
   v_tot_egresos    cr_per_ing_egresos.importe%type;
   v_tot_ingreso    cr_per_ing_egresos.importe%type;
   v_net_egresos    cr_per_ing_egresos.importe%type;
   v_net_ingreso    cr_per_ing_egresos.importe%type;
   v_cod_mon_local  ba_monedas.cod_moneda%type;

/* Obtener total de egresos del cliente. */
FUNCTION FL_OBT_TOT_ING_EGR
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_TIPO IN CR_CON_ING_EGR.TIPO%TYPE
 )
 RETURN NUMBER
 IS
--- Variables
   v_mto_cuota        pr_cuotas.mto_capital%type;
BEGIN
   select nvl(sum(nvl(importe,0)),0) importe
     into v_mto_cuota
     from cr_per_ing_egresos
    where cod_persona = p_cod_persona
      and ing_egreso = p_tipo;
   return v_mto_cuota;
END;
begin
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   -- Recuperar cuotas de nuestra entidad
   v_cuo_entidad := fug_obt_cuo_entidad(p_cod_persona, v_cod_mon_local);
   -- Recuperar cuotas de otras entidades
   v_cuo_otr_fin := fug_obt_cuo_otr_ent(p_cod_persona, v_cod_mon_local);
   -- Recuperar total de egresos
   v_tot_egresos := FL_OBT_TOT_ING_EGR(p_cod_persona, v_cod_mon_local,'E');
   -- Recuperar total de ingresos
   v_tot_ingreso := FL_OBT_TOT_ING_EGR(p_cod_persona, v_cod_mon_local,'I');
   -- Calcular porcentaje
   v_net_egresos := nvl(v_cuo_entidad,0)+nvl(v_cuo_otr_fin,0)+nvl(v_tot_egresos,0);
   v_net_ingreso := nvl(v_tot_ingreso,0);
   if nvl(v_net_ingreso,0) > 0 then
      result := round(((v_net_egresos / v_net_ingreso) * 100),2);
   else
      result := -1;
   end if;
   -- Retorna el porcentaje de endeudamiento de la persona
   return(Result);
exception
   when no_data_found then
      return (0);
   when others then
      raise_application_error(-20000,'fug_niv_endeudamiento '||sqlerrm);
end;
/

