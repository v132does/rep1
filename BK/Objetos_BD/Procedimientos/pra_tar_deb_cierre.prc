CREATE OR REPLACE PROCEDURE IT.PRA_TAR_DEB_CIERRE
 IS
begin
  -- envia RENOVACIONES y TARJETAS NUEVAS

  -- Todas las tarjetas vencidas por Cuentas Corrientes más
  -- Todas las tarjetas vencidas por Cajas de Ahorro.
  --
  declare
  v_lugar         varchar2(100);
  v_fec_ahorros   date := pag_cal.FU_OBT_FEC_ACTUAL(3);
  v_fec_ctacte    date := pag_cal.FU_OBT_FEC_ACTUAL(4);
  v_fec_actual    Date := to_date(to_char(Sysdate,'dd/mm/yyyy')||to_char(Sysdate,'hh24:mi:ss') , 'dd/mm/yyyy hh24:mi:ss');
  v_tot_renovadas number(10) := 0 ;
  v_tot_nuevas    number(10) := 0 ;
  v_tot_rel_ctas  number(10) := 0;
  v_cod_ent_pro_ant ah_tar_debitos.cod_ent_procesadora%type;

/*  Cursor Vencidas is
  select t.nro_cuenta, t.adherente ,
         lpad(to_char(to_number(t.nro_emision)+1), 2, '0') NuevaEmision,
         nvl(t.cod_ofi_origen,g.cod_oficina) cod_ofi_origen, t.embozado,
         to_date(to_char(last_day(add_months(t.fec_vencimiento,24)), 'DD/MM/YYYY'), 'DD/MM/YYYY') fec_vencimiento,
         t.fec_ingreso, t.cod_persona, t.nro_emision,
         g.cod_modulo , t.tip_envio,t.referencia, t.cod_ent_procesadora
    from cc_cta_corrientes c , ge_clientes l , ge_cta_clientes g, ah_Tar_debitos t
   where t.nro_cuenta  = g.nro_cuenta
     and t.nro_cuenta  = c.nro_cuenta
     and g.cod_persona = l.cod_persona
     and c.estado = 'N'
     and to_char(t.fec_vencimiento, 'yyyymm') = to_char(v_fec_ctacte, 'yyyymm')
     and t.cod_est_solicitud not in(16, 17)   --- No toma las anuladas ni las de No Utilización del Plastico
   union
  select t.nro_cuenta , t.adherente, lpad(to_char(to_number(t.nro_emision)+1), 2, '0') NuevaEmision,
         nvl(t.cod_ofi_origen,g.cod_oficina ), t.embozado,
         to_date(to_char(last_day(add_months(t.fec_vencimiento,24)), 'DD/MM/YYYY'), 'DD/MM/YYYY') fec_vencimiento,
         t.fec_ingreso, t.cod_persona, t.nro_emision,
         g.cod_modulo , t.tip_envio,t.referencia, t.cod_ent_procesadora
    from ah_cta_vistas v , ge_cta_clientes g , ge_clientes l, ah_tar_debitos t
   where t.nro_cuenta  = g.nro_cuenta
     and t.nro_cuenta  = v.nro_cuenta
     and g.cod_persona = l.cod_persona
     and v.estado = 'N'
     and to_char(t.fec_vencimiento, 'yyyymm') = to_char(v_fec_ahorros, 'yyyymm')
     and t.cod_est_solicitud not in(16, 17) --- No toma las anuladas ni las de No Utilización del Plastico
   order by 13,1;*/
BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO:=1;

  v_lugar := 'Antes de empezar renovaciones';
  v_cod_ent_pro_ant := null;
/*  For TarjVenc in Vencidas Loop
    v_lugar := 'En el loop de renovaciones';
    -- Corte de control por procesadora
    if v_cod_ent_pro_ant is null then
       -- La primera vez
       v_cod_ent_pro_ant := TarjVenc.cod_ent_procesadora;
    end if;
    if v_cod_ent_pro_ant <> TarjVenc.cod_ent_procesadora then
       v_lugar := 'Actualizando AH_TAR_DEBITOS NUEVAS ...';
       update AH_TAR_DEBITOS a
          set cod_est_solicitud = 5,
              fec_envio         = v_fec_actual
        where cod_est_solicitud = '3'
          and cod_ent_procesadora = v_cod_ent_pro_ant
          and exists (select 0 from ge_cuentas b
                       where b.nro_cuenta = a.nro_cuenta
                         and b.estado IN( 'N', 'A', 'I','S')) ;
       v_tot_nuevas := sql%rowcount;
       v_lugar := 'Insertando en AH_TAR_DEB_ENVIOS ...';
       if v_tot_renovadas > 0 or v_tot_nuevas > 0 then
          begin
            insert into AH_TAR_DEB_ENVIOS(
                           FEC_PROCESO,
                           ESTADO,
                           CAN_TAR_NUEVAS,
                           CAN_TAR_RENOVADAS,
                           COD_ENT_PROCESADORA)
                   values (v_fec_actual,
                          'G',
                          v_tot_nuevas,
                          v_tot_renovadas,
                          v_cod_ent_pro_ant );
          Exception
           When Others then
             RAISE_APPLICATION_ERROR(20001,'ERROR EN PRA_TAR_DEB_CIERRES '||V_LUGAR||SQLERRM);
          end;
       end if;
       --- Inicializar variables
       v_tot_renovadas := 0;
       v_tot_nuevas    := 0;
       v_cod_ent_pro_ant := TarjVenc.cod_ent_procesadora;
    end if;
    --
    -- Inserta las Tarjetas a renovar en la tabla AH_TAR_DEBITOS con
    -- nuevo número de emisión y estado pendiente de solicitud.
    v_lugar := 'Generando : '||tarjvenc.nro_cuenta;
    --
    v_tot_renovadas := v_tot_renovadas + 1 ;
    insert into ah_tar_debitos
    ( nro_cuenta,
      tar_activa,
      fec_ingreso,
      cod_persona,
      embozado,
      cod_usuario,
      fec_grabacion,
      adherente,
      nro_emision,
      cod_est_solicitud,
      cod_causa,
      cod_ofi_origen,
      fec_recepcion,
      fec_entrega,
      fec_ult_impresion,
      fec_vencimiento,
      fec_cancelacion,
      nro_planilla,
      tip_planilla,
      motivo,
      nro_pla_anterior,
      fec_envio ,
      tip_envio,
      referencia,
      cod_ent_procesadora)
    values (TarjVenc.nro_cuenta,
            'S',
            Decode(TarjVenc.cod_modulo, 3, v_fec_ahorros, 4, v_fec_ctacte),
            TarjVenc.cod_persona,
            TarjVenc.embozado,
            user,
            Decode(TarjVenc.cod_modulo, 3, v_fec_ahorros, 4, v_fec_ahorros),
            TarjVenc.adherente,
            TarjVenc.NuevaEmision,
            '2', -- A aprobar por el operativo
            null,
            TarjVenc.cod_ofi_origen,
            null,
            null,
            TarjVenc.fec_ingreso,
            TarjVenc.fec_vencimiento,
            null,
            null,
            null,
            null,
            null,
            v_fec_actual,
            TarjVenc.tip_envio,
            TarjVenc.referencia,
            TarjVenc.cod_ent_procesadora);

    --
    -- Al número de emisión anterior la cancela y le inserta la fecha de cancelacion
    --
   v_lugar := 'Actualizando AH_TAR_DEBITOS RENOVADAS ...';

    update AH_TAR_DEBITOS
       set cod_est_solicitud = '16',
           fec_cancelacion = trunc(v_fec_actual)
     where nro_cuenta  = TarjVenc.nro_cuenta
       and adherente   = TarjVenc.adherente
       and nro_emision = TarjVenc.nro_emision
       and cod_ent_procesadora = TarjVenc.cod_ent_procesadora;

  End Loop;*/

  if v_cod_ent_pro_ant is not null then
    v_lugar := 'Actualizando AH_TAR_DEBITOS NUEVAS ...';
    update AH_TAR_DEBITOS a
       set cod_est_solicitud = 5,
           fec_envio         = v_fec_actual
     where cod_est_solicitud = '3'
       and cod_ent_procesadora = v_cod_ent_pro_ant
       and exists (select 0 from ge_cuentas b
                    where b.nro_cuenta = a.nro_cuenta
                      and b.estado IN( 'N', 'A', 'I','S')) ;
    v_tot_nuevas := sql%rowcount;

    v_lugar := 'Actualizando AH_TAR_DEBITOS RELACION DE CUENTAS ...';
    update AH_TAR_DEB_CUENTAS a
       set fec_envio         = v_fec_actual
     where cod_ent_procesadora = v_cod_ent_pro_ant
       and fec_envio is null
       and exists (select 0 from ge_cuentas b
                    where b.nro_cuenta = a.nro_cuenta
                      and b.estado IN( 'N', 'A', 'I','S'))
       and exists (select 0 from ge_cuentas b
                    where b.nro_cuenta = a.nro_cta_relacionada
                      and b.estado IN( 'N', 'A', 'I','S'));
    v_tot_rel_ctas := sql%rowcount;

    v_lugar := 'Insertando en AH_TAR_DEB_ENVIOS ...';
    if v_tot_renovadas > 0 or v_tot_nuevas > 0 then
      begin
       insert into AH_TAR_DEB_ENVIOS(
                      FEC_PROCESO,
                      ESTADO,
                      CAN_TAR_NUEVAS,
                      CAN_TAR_RENOVADAS,
                      CAN_REL_CUENTAS,
                      COD_ENT_PROCESADORA)
               values (v_fec_actual,
                       'G',
                       v_tot_nuevas,
                       v_tot_renovadas,
                       v_tot_rel_Ctas,
                       v_cod_ent_pro_ant );
      Exception
        When Others then
          RAISE_APPLICATION_ERROR(20001,'ERROR EN PRA_TAR_DEB_CIERRES '||V_LUGAR||SQLERRM);
      end;
    end if;
  else
    --- No existen tarjetas vencidas y no entra en el ciclo
    v_lugar := 'Insertando en AH_TAR_DEB_ENVIOS masivo ...';
    v_cod_ent_pro_ant := fug_obt_pardinamico('COD_PRO_BANCARD');
    Select count(*) into v_tot_nuevas
       from ah_Tar_debitos a
     where cod_est_solicitud = '3'
       and exists (select 0 from ge_cuentas b
                    where b.nro_cuenta = a.nro_cuenta
                      and b.estado IN( 'N', 'A', 'I','S'));
                      
    Select count(*) into v_tot_rel_Ctas
       from ah_Tar_deb_cuentas a
     where fec_envio is null
       and exists (select 0 from ge_cuentas b
                    where b.nro_cuenta = a.nro_cuenta
                      and b.estado IN( 'N', 'A', 'I','S'))
       and exists (select 0 from ge_cuentas b
                    where b.nro_cuenta = a.nro_cta_relacionada
                      and b.estado IN( 'N', 'A', 'I','S'));
    
    insert into AH_TAR_DEB_ENVIOS(
                      FEC_PROCESO,
                      ESTADO,
                      CAN_TAR_NUEVAS,
                      CAN_TAR_RENOVADAS,
                      CAN_REL_CUENTAS,
                      COD_ENT_PROCESADORA)
     Values
     (v_Fec_actual, 'G', v_tot_nuevas, 0, v_tot_rel_ctas, v_cod_ent_pro_ant);
    --
    v_lugar := 'Actualizando AH_TAR_DEBITOS NUEVAS masivo ...';
    update AH_TAR_DEBITOS a
       set cod_est_solicitud = 5,
           fec_envio         = v_fec_actual
     where cod_est_solicitud = '3'
       and exists (select 0 from ge_cuentas b
                    where b.nro_cuenta = a.nro_cuenta
                      and b.estado IN( 'N', 'A', 'I','S')) ;
                      
    update AH_TAR_DEB_CUENTAS a
       set fec_envio         = v_fec_actual
     where fec_envio is null
       and exists (select 0 from ge_cuentas b
                    where b.nro_cuenta = a.nro_cuenta
                      and b.estado IN( 'N', 'A', 'I','S'))
       and exists (select 0 from ge_cuentas b
                    where b.nro_cuenta = a.nro_cta_relacionada
                      and b.estado IN( 'N', 'A', 'I','S'));
                      
  end if;
END;

end PRA_TAR_DEB_CIERRE;
/

