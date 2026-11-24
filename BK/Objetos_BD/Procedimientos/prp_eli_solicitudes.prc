CREATE OR REPLACE PROCEDURE IT.PRP_ELI_SOLICITUDES (P_NRO_SOLICITUD IN NUMBER DEFAULT NULL) is
  v_fec_actual    date := pag_cal.FU_OBT_FEC_ACTUAL(6);
  v_ult_fec_habil date;
  rg_calendar     ge_calendarios%rowtype;
  v_frecuencia    ge_procesos_det.frecuencia%type := 'D';
  v_exi_sol_resol4 varchar2(1);
  v_nue_cal_seguros ge_par_dinamicos.val_parametro%type;
  Cursor c1 is
     SELECT a.nro_solicitud, a.nro_linea, a.cod_modalidad
      FROM pr_solicitudes a, pr_sol_garantias b, ba_tab_def_adicionales d
     WHERE a.nro_solicitud = b.nro_solicitud
       AND d.tab_relacion = 'PR_GAR_TIPOS'
       AND d.parametro = 'ESTADO_' || a.estado
       AND (d.tipo IS NULL OR instr(',' || d.tipo || ',', b.cod_garantia) > 0)
       AND a.nro_solicitud = nvl(p_nro_solicitud, a.nro_solicitud)
       AND a.fec_inicio <= v_fec_actual - fue_tab_dat_adicional('PR_GAR_TIPOS', 'ESTADO_' || a.estado, b.cod_garantia)
       AND v_frecuencia = 'M'
     UNION  --CROLIANC-4 AT
    SELECT a.nro_solicitud, a.nro_linea, a.cod_modalidad
      FROM pr_solicitudes a, pr_sol_garantias b, ba_tab_def_adicionales d
     WHERE a.nro_solicitud = b.nro_solicitud
       AND d.tab_relacion = 'PR_GAR_TIPOS'
       AND d.parametro = 'ESTADO_' || a.estado
       AND (d.tipo IS NULL OR instr(',' || d.tipo || ',', b.cod_garantia) > 0)
       AND a.nro_solicitud = nvl(p_nro_solicitud, a.nro_solicitud)
       AND a.cod_modalidad = 699;
   v_nro_linea pr_lineas.nro_linea%type;
   v_exi_cta_cobranzas varchar2(1);
   v_exi_cta_exportaciones varchar2(1);
   v_exi_cta_importaciones varchar2(1);

begin
   /*
   || CROLIANC-4 AT - Liberacion Anticipada Cheques C/O con Creación de Cuentas de Préstamos.
   */
   rg_calendar := pag_cal.FU_OBT_REG_CAL(6);
   v_ult_fec_habil := rg_calendar.ult_dia_mes_habil;
   if v_fec_actual = v_ult_fec_habil and P_NRO_SOLICITUD is null then
      v_frecuencia := 'M';
   else
      v_frecuencia := 'D';
   end if;
   ---
  For r1 in c1 Loop
    begin
      select distinct('S')
        into v_exi_cta_cobranzas
        from cx_cta_cobranzas
       where nro_sol_prestamo = r1.nro_solicitud;
    exception
      when others then
        v_exi_cta_cobranzas := 'N';
    end;

    begin
      select distinct('S')
        into v_exi_cta_exportaciones
        from cx_cta_exportaciones
       where nro_sol_prestamo = r1.nro_solicitud;
    exception
      when others then
        v_exi_cta_exportaciones := 'N';
    end;

    begin
      select distinct('S')
        into v_exi_cta_importaciones
        from cx_cta_importaciones
       where nro_sol_prestamo = r1.nro_solicitud;
    exception
      when others then
        v_exi_cta_importaciones := 'N';
    end;

    if nvl(v_exi_cta_cobranzas, 'N') <> 'S' and
       nvl(v_exi_cta_exportaciones, 'N') <> 'S' and
       nvl(v_exi_cta_importaciones, 'N') <> 'S' then
      v_nro_linea := r1.nro_linea;
      
      --Verificar p/ Elimin. Solicitudes Resol4--
      v_exi_sol_resol4 := 'N';
      select decode(nvl(count(*),0),0,'N','S')
        into v_exi_sol_resol4
        from pr_cta_pre_ref_res4 a
       where a.nro_sol_nueva = r1.nro_solicitud;    
      
      if nvl(v_exi_sol_resol4,'N') = 'S' then
         v_nue_cal_seguros := null;
         v_nue_cal_seguros := nvl(fug_obt_pardinamico('PRE_NUE_CAL_SEGUROS',6,r1.nro_solicitud),'N');
         if nvl(v_nue_cal_seguros,'N') = 'S' then
            delete from BA_TAB_DAT_ADICIONALES X
             where x.tab_relacion = 'PR_SOLICITUDES'
               and x.parametro = 'PRE_IND_CUO_CAL_SEGURO'
               and x.referencia = to_char(r1.nro_solicitud);
         end if;
         
         --Eliminacion de Tabla espejo Resol4--
         delete from pr_cta_pre_ref_res4 a
          where a.nro_sol_nueva = r1.nro_solicitud;
         
         --Actualizacion maestro Prestamos--
         update pr_cta_prestamos
            set nro_sol_renovada = null,
                nro_cta_renovada = null
          where nro_sol_renovada = r1.nro_solicitud;
   
         --Actualizacion maestro Oper. Vencidas--
         update ov_cta_vencidas
            set nro_sol_renovada = null,
                nro_cta_renovada = null
          where nro_sol_renovada = r1.nro_solicitud;          
      end if;     
      ---------------------------
      
      Delete from pr_sol_cuotas
       where nro_solicitud = r1.nro_solicitud;
      Delete from pr_sol_cargos
       where nro_solicitud = r1.nro_solicitud;
      Delete from pr_sol_garantias
       where nro_solicitud = r1.nro_solicitud;
      Delete from pr_sol_tasas
       where nro_solicitud = r1.nro_solicitud;
      Delete from pr_sol_destinos
       where nro_solicitud = r1.nro_solicitud;
      Delete from pr_sol_gestiones
       where nro_solicitud = r1.nro_solicitud;
      --Proyecto SDSEGVID-3. Eliminacion reg. en tabla aux de Seg Vida Distr--
      Delete from pr_cta_gas_seguros
       where nro_solicitud = r1.nro_solicitud;
      -------------------------------------------
      Delete from pr_solicitudes
       where nro_solicitud = r1.nro_solicitud;
      If v_nro_linea is not null then
         prp_rec_apl_limite(v_nro_linea);
      End If;
    end if;
    /*
    || CROLIANC-4 AT - Liberacion Anticipada Cheques C/O con Creación de Cuentas de Préstamos.
    */
    update ah_retenciones r
       set r.lib_anticipada = 'N'
     where exists (select 1
                     from cc_lib_ant_cheques a
                    where a.nro_sol_prestamo = r1.nro_solicitud
                      and a.nro_cuenta = r.nro_cuenta
                      and a.nro_documento = r.nro_documento
                      and a.cod_retencion = r.cod_retencion
                      and a.fec_final = r.fec_final);
    Delete from cc_lib_ant_cheques
     where nro_sol_prestamo = r1.nro_solicitud;
  End Loop;
end PRP_ELI_SOLICITUDES;
/

