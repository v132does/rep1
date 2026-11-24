create or replace procedure it.prp_gen_det_gar_com IS
   /*Genera Detalle de Garantias Computables*/
   /*PCCDEEVO-901 - Desglose de Garantias Computables*/

   --Variables--
   v_fecha date;
   --v_ult_dia_mes_habil date;
   v_cod_mon_local ba_monedas.cod_moneda%type;
   v_gar_compu  pr_cta_garantias.mto_apl_computable%type;
   v_gar_com_ml pr_cta_garantias.mto_con_computable%type;
   v_nro_cuenta ge_cuentas.nro_cuenta%type;
   v_cod_modulo ba_modulos.cod_modulo%type;
   v_cod_modalidad ge_modalidades.cod_modalidad%type;
   v_exi_det_garantia varchar2(1);

   --Cursores--
   cursor c_cta_clasif is
   select a.nro_cuenta, a.cod_modulo, a.cod_modalidad
     from ge_cla_operaciones a
    where nvl(a.tot_gar_computables,0) > 0;

   CURSOR c_gar_prestamos IS
   SELECT g.nro_cuenta, g.nro_garantia, g.cod_garantia, g.cod_persona,
          k.cod_moneda, g.mto_apl_computable, p.cod_moneda cod_mon_gar
     FROM pr_cta_garantias g, pr_gar_tipos t, pr_cta_prestamos k, pr_garantias  p
    WHERE g.nro_cuenta = v_nro_cuenta
      and g.cod_garantia = t.cod_garantia
      and g.nro_garantia = p.nro_garantia
      and t.computable = 'S'
      and nvl(g.mto_apl_computable,0) > 0
      and k.nro_cuenta = g.nro_cuenta;

   CURSOR c_gar_tarjetas IS
   SELECT g.nro_cuenta, g.nro_garantia, g.cod_garantia, g.cod_persona,
          k.cod_moneda, g.mto_apl_computable, p.cod_moneda cod_mon_gar
     FROM ta_cta_garantias g, pr_gar_tipos t, ta_cta_tarjetas k, pr_garantias  p
    WHERE g.nro_cuenta = v_nro_cuenta
      and g.cod_garantia = t.cod_garantia
      and g.nro_garantia = p.nro_garantia
      and t.computable = 'S'
      and nvl(g.mto_apl_computable,0) > 0
      and k.nro_cuenta = g.nro_cuenta;

   CURSOR c_gar_ctacte IS
   SELECT g.nro_cuenta, g.nro_garantia, g.cod_garantia, g.cod_persona,
          k.cod_moneda, g.mto_apl_computable, p.cod_moneda cod_mon_gar
     FROM cc_cta_garantias g, pr_gar_tipos t, cc_cta_corrientes k, pr_garantias  p
    WHERE g.nro_cuenta = v_nro_cuenta
      and g.cod_garantia = t.cod_garantia
      and g.nro_garantia = p.nro_garantia
      and t.computable = 'S'
      and nvl(g.mto_apl_computable,0) > 0
      and k.nro_cuenta = g.nro_cuenta;

   CURSOR c_gar_comex IS
   SELECT g.nro_cuenta, g.nro_garantia, g.cod_garantia, g.cod_persona,
          k.cod_moneda, g.mto_apl_computable, p.cod_moneda cod_mon_gar
     FROM cx_cta_garantias g, pr_gar_tipos t, ge_cuentas k, pr_garantias  p
    WHERE g.nro_cuenta = v_nro_cuenta
      and g.cod_garantia = t.cod_garantia
      and g.nro_garantia = p.nro_garantia
      and t.computable = 'S'
      and nvl(g.mto_apl_computable,0) > 0
      and k.nro_cuenta = g.nro_cuenta;

   CURSOR c_gar_ctaven IS
   SELECT g.nro_cuenta, g.nro_garantia, g.cod_garantia, g.cod_persona,
          k.cod_moneda, g.mto_apl_computable, p.cod_moneda cod_mon_gar
     FROM ov_cta_garantias g, pr_gar_tipos t, ov_cta_vencidas k, pr_garantias  p
    WHERE g.nro_cuenta = v_nro_cuenta
      and g.cod_garantia = t.cod_garantia
      and g.nro_garantia = p.nro_garantia
      and t.computable = 'S'
      and nvl(g.mto_apl_computable,0) > 0
      and k.nro_cuenta = g.nro_cuenta;
   
   CURSOR c_contra IS
   select x.nro_cuenta, v_fecha fecha, 1 nro_garantia, 18 cod_garantia, y.cod_persona, z.cod_moneda,
          x.difer mto_apl_computable, z.cod_modulo, z.cod_modalidad
     from ge_cta_clientes y, ge_cuentas z,
   (
   SELECT 'ge_cla_operaciones' tipo, a.cod_modulo,
          a.nro_cuenta, a.cod_estado,
          NVL(A.TOT_GAR_COMPUTABLES,0) MTO_GAR_COM,
          MTO_GAR_det, NVL(A.TOT_GAR_COMPUTABLES,0) - nvl(MTO_GAR_det,0) difer, CAN_GAR
     FROM GE_CLA_OPERACIONES A,
          (SELECT x.nro_cuenta,
                  SUM(NVL(x.mto_apl_com_ml,0)) MTO_GAR_det,
                  COUNT(*) CAN_GAR
             FROM PR_CTA_GARANTIAS_DET X
            where x.fecha = v_fecha
          group by x.nro_cuenta) det
    WHERE a.nro_cuenta = det.nro_cuenta(+)
      and (NVL(A.TOT_GAR_COMPUTABLES,0) - nvl(MTO_GAR_det,0)) <> 0
      and (a.cod_modulo = 8 and a.cod_estado = 'A')
   ) x
    where x.nro_cuenta = y.nro_cuenta
      and y.relacion = 'P'
      and z.nro_cuenta = x.nro_cuenta;
BEGIN
   
   --Carga de Variables--
   v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
   pag_cal.pr_obt_dat_calendar(6);
   v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(6);
   --v_ult_dia_mes_habil := pag_cal.g_ult_dia_mes_habil;
   
   --Ejecutar el Ultimo dia Habil del Mes--
   /*
   || Modificacion garantías computables
   || Ejecutar diariamente
   */
   --if v_fecha = v_ult_dia_mes_habil then
       --Valida y Elimina Registros anteriores--
       select decode(nvl(count(*),0),0,'N','S')
         into v_exi_det_garantia
         from pr_cta_garantias_det y
        where y.fecha = v_fecha;
       if v_exi_det_garantia = 'S' then
          delete from  pr_cta_garantias_det y
           where y.fecha = v_fecha;
       end if;

       --Cursor de Procesamiento Principal--
       for cue in c_cta_clasif loop
         v_nro_cuenta := cue.nro_cuenta;
         v_cod_modulo := cue.cod_modulo;
         v_cod_modalidad := cue.cod_modalidad;
         if cue.cod_modulo = 6 then
             FOR reg IN c_gar_prestamos LOOP
                v_gar_compu := nvl(reg.mto_apl_computable,0);
                if reg.cod_moneda = v_cod_mon_local then
                   v_gar_com_ml := nvl(v_gar_compu,0);
                else
                   v_gar_com_ml := round(fub_con_mon_a_moneda(reg.cod_moneda,v_cod_mon_local,v_gar_compu),0);
                end if;

                insert into pr_cta_garantias_det
                (nro_cuenta, fecha, nro_garantia, cod_garantia, cod_persona,
                 mto_apl_computable, mto_apl_com_ml, cod_moneda, cod_modulo, cod_modalidad)
                values
                (reg.nro_cuenta, v_fecha, reg.nro_garantia, reg.cod_garantia, reg.cod_persona,
                 v_gar_compu, v_gar_com_ml, reg.cod_mon_gar, v_cod_modulo, v_cod_modalidad);

             END LOOP;
         elsif cue.cod_modulo = 5 then
             FOR reg IN c_gar_tarjetas LOOP
                v_gar_compu := nvl(reg.mto_apl_computable,0);
                if reg.cod_moneda = v_cod_mon_local then
                   v_gar_com_ml := nvl(v_gar_compu,0);
                else
                   v_gar_com_ml := round(fub_con_mon_a_moneda(reg.cod_moneda,v_cod_mon_local,v_gar_compu),0);
                end if;

                insert into pr_cta_garantias_det
                (nro_cuenta, fecha, nro_garantia, cod_garantia, cod_persona,
                 mto_apl_computable, mto_apl_com_ml, cod_moneda, cod_modulo, cod_modalidad)
                values
                (reg.nro_cuenta, v_fecha, reg.nro_garantia, reg.cod_garantia, reg.cod_persona,
                 v_gar_compu, v_gar_com_ml, reg.cod_mon_gar, v_cod_modulo, v_cod_modalidad);

             END LOOP;
         elsif cue.cod_modulo = 4 then
             FOR reg IN c_gar_ctacte LOOP
                v_gar_compu := nvl(reg.mto_apl_computable,0);
                if reg.cod_moneda = v_cod_mon_local then
                   v_gar_com_ml := nvl(v_gar_compu,0);
                else
                   v_gar_com_ml := round(fub_con_mon_a_moneda(reg.cod_moneda,v_cod_mon_local,v_gar_compu),0);
                end if;

                insert into pr_cta_garantias_det
                (nro_cuenta, fecha, nro_garantia, cod_garantia, cod_persona,
                 mto_apl_computable, mto_apl_com_ml, cod_moneda, cod_modulo, cod_modalidad)
                values
                (reg.nro_cuenta, v_fecha, reg.nro_garantia, reg.cod_garantia, reg.cod_persona,
                 v_gar_compu, v_gar_com_ml, reg.cod_mon_gar, v_cod_modulo, v_cod_modalidad);
                 
             END LOOP;
         elsif cue.cod_modulo = 8 then
             FOR reg IN c_gar_comex LOOP
                v_gar_compu := nvl(reg.mto_apl_computable,0);
                if reg.cod_moneda = v_cod_mon_local then
                   v_gar_com_ml := nvl(v_gar_compu,0);
                else
                   v_gar_com_ml := round(fub_con_mon_a_moneda(reg.cod_moneda,v_cod_mon_local,v_gar_compu),0);
                end if;

                insert into pr_cta_garantias_det
                (nro_cuenta, fecha, nro_garantia, cod_garantia, cod_persona,
                 mto_apl_computable, mto_apl_com_ml, cod_moneda, cod_modulo, cod_modalidad)
                values
                (reg.nro_cuenta, v_fecha, reg.nro_garantia, reg.cod_garantia, reg.cod_persona,
                 v_gar_compu, v_gar_com_ml, reg.cod_mon_gar, v_cod_modulo, v_cod_modalidad);
                 
             END LOOP;
         elsif cue.cod_modulo = 15 then
             FOR reg IN c_gar_ctaven LOOP
                v_gar_compu := nvl(reg.mto_apl_computable,0);
                if reg.cod_moneda = v_cod_mon_local then
                   v_gar_com_ml := nvl(v_gar_compu,0);
                else
                   v_gar_com_ml := round(fub_con_mon_a_moneda(reg.cod_moneda,v_cod_mon_local,v_gar_compu),0);
                end if;

                insert into pr_cta_garantias_det
                (nro_cuenta, fecha, nro_garantia, cod_garantia, cod_persona,
                 mto_apl_computable, mto_apl_com_ml, cod_moneda, cod_modulo, cod_modalidad)
                values
                (reg.nro_cuenta, v_fecha, reg.nro_garantia, reg.cod_garantia, reg.cod_persona,
                 v_gar_compu, v_gar_com_ml, reg.cod_mon_gar, v_cod_modulo, v_cod_modalidad);
                 
             END LOOP;
         end if;
         
       end loop;

       --Eliminacion de Ctas Morosas y Bloqueadas--
       delete from PR_CTA_GARANTIAS_DET Z
        where z.fecha = v_fecha
          and exists (
        SELECT 'ge_cla_operaciones' tipo, a.cod_modulo,
               a.nro_cuenta, a.cod_estado,
               NVL(A.TOT_GAR_COMPUTABLES,0) MTO_GAR_COM,
               MTO_GAR_det, NVL(A.TOT_GAR_COMPUTABLES,0) - nvl(MTO_GAR_det,0) difer, CAN_GAR
        FROM GE_CLA_OPERACIONES A,
        (SELECT x.nro_cuenta,
                SUM(NVL(x.mto_apl_com_ml,0)) MTO_GAR_det,
                COUNT(*) CAN_GAR
           FROM PR_CTA_GARANTIAS_DET x
          where x.fecha = v_fecha
          group by x.nro_cuenta) det
        WHERE a.nro_cuenta = det.nro_cuenta(+)
          and (NVL(A.TOT_GAR_COMPUTABLES,0) - nvl(MTO_GAR_det,0)) <> 0
          and a.nro_cuenta = z.nro_cuenta
          and ((a.cod_modulo in (6,15) and a.cod_estado = 'M') or (a.cod_modulo = 5 and a.cod_estado = 'B'))
                     );
    
   -- Modificacion garantías computables --
   FOR reg IN c_contra LOOP
      
       --Insercion de Contra Garantias--
       insert into PR_CTA_GARANTIAS_DET t
        (nro_cuenta, fecha, nro_garantia, cod_garantia, cod_persona,
         cod_moneda, mto_apl_com_ml, cod_modulo, cod_modalidad)
       values(reg.nro_cuenta, reg.fecha, reg.nro_garantia, reg.cod_garantia, reg.cod_persona,
              reg.cod_moneda, reg.mto_apl_computable, reg.cod_modulo, reg.cod_modalidad);
      
   end loop;
   --end if;

EXCEPTION
  When Others Then
       raise_application_error (-20000,'Error en prp_gen_det_gar_com: '||sqlerrm);
END prp_gen_det_gar_com;
/

