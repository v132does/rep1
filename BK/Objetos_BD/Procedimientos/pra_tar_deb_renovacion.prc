CREATE OR REPLACE PROCEDURE IT.PRA_TAR_DEB_RENOVACION (P_ANO IN NUMBER, P_MES IN NUMBER, P_MSG OUT VARCHAR2)
 IS
  -- Procesa las RENOVACIONES de todas las tarjetas vencidas por Cuentas Corrientes más
  -- todas las tarjetas vencidas por Cajas de Ahorro.
  --
  v_lugar           varchar2(100);
  v_fec_ahorros     date := pag_cal.FU_OBT_FEC_ACTUAL(3);
  v_fec_ctacte      date := pag_cal.FU_OBT_FEC_ACTUAL(4);
  v_fec_actual      Date := to_date(to_char(Sysdate,'dd/mm/yyyy')||to_char(Sysdate,'hh24:mi:ss') , 'dd/mm/yyyy hh24:mi:ss');
  v_nueva_emision   ah_tar_Debitos.nro_emision%type;
  v_nuevo_adherente ah_tar_Debitos.adherente%type;
  v_fec_vencimiento date;
  v_anio_vencimiento     number := fug_obt_pardinamico('VEN_TAR_DEBITOS');
  v_cod_procesadora      ah_tar_debitos.cod_ent_procesadora%type := fug_obt_pardinamico('COD_PRO_BANCARD');
  v_nro_bin_procesadora  ah_tar_debitos.nro_bin%type;
  v_nro_bin_visa         ah_tar_debitos.nro_bin%type := fug_obt_parentes(v_cod_procesadora, 'NRO_BIN_TAR_DEBITO');
  v_renovacion           varchar2(1);
  v_tip_tar_deb          ah_tar_Debitos.tip_tar_debito%type;
  v_tot_renovadas        number;
  v_cod_causa            ah_tar_debitos.cod_causa%type := '295';--DYDMR-7138--Se agrega cod_causal RENOVACION POR VENCIMIENTO para las renovac. de TDD para el envío de acción a Infonet.
  
  v_cod_pro_bancard     VARCHAR2(10) := fug_obt_pardinamico('COD_PRO_BANCARD', NULL, NULL, NULL, NULL);
  v_mto_ref_tdd_infonet ge_pag_sue_emp_tmp.sueldo%type := to_number(fug_obt_pardinamico('MTO_SUELDO_TDD_INFONET'));
  v_nro_bin_tdd_infonet ah_tar_debitos.nro_bin%TYPE := fug_obt_parentes(v_cod_pro_bancard, 'NRO_BIN_TDD_INFONET');--TDD NUEVO BIN
  v_tip_tdd_infonet     ah_tar_Debitos.tip_tar_debito%type;
  v_tie_mov_ext         varchar2(1);
  v_plz_mes_mov_exterior number(2) := to_number(  fug_obt_pardinamico('TDD_PLZ_MES_MOV_EXTERIOR'));  --cantidad de meses a buscar para atrás de mov extranjeros                     
  ---
   v_hab_tdd_mastercard varchar2(1) := fug_obt_pardinamico( 'HAB_TDD_MASTERCARD' );
   v_nro_bin_mastercard number  := fug_obt_parentes(fug_obt_pardinamico('COD_PRO_BANCARD'),'NRO_BIN_TDD_MASTERCARD');  -- Nro. BIN

  ---{
  ----DYDMR-6822
  v_err_ctas varchar2(200); --acumulamos las ctas con error.
  ------------
  --Cursor de las tarjetas a renovar
  Cursor Vencidas is
  select t.nro_cuenta, t.adherente ,
         nvl(t.cod_ofi_origen,g.cod_oficina) cod_ofi_origen, t.embozado,
         fec_vencimiento,
         t.fec_ingreso, t.cod_persona, t.nro_emision,
         g.cod_modulo , t.tip_envio,t.referencia, t.cod_ent_procesadora,
         c.cod_moneda, nro_bin, tip_tar_Debito, (select sum(t.mto_ingreso)
                                                  from CR_INF_LABORALES T
                                                 where T.ACTUAL = 'S'
                                                   --and T.MTO_FIJO = 'S'
                                                   and t.cod_persona = l.cod_persona) mto_ingreso, c.cod_modalidad
        -- fug_tie_mov_extranjero(c.nro_cuenta, c.cod_modalidad,-12) mov_ext
    from ah_Tar_debitos t, cc_cta_corrientes c, ge_cta_clientes g, ge_clientes l 
   where t.nro_cuenta  = g.nro_cuenta
     and t.nro_cuenta  = c.nro_cuenta
     and g.cod_persona = l.cod_persona
     and t.cod_persona = g.cod_persona--Ajuste para que no duplique (Cuando tiene varios firmantes)
     and c.estado in('N','A','S')
     and to_number(to_char(t.fec_vencimiento, 'yyyymm')) = to_number(p_ano||lpad(to_char(p_mes),2,'0'))
     and t.cod_est_solicitud not in(16, 17)   --- No toma las anuladas ni las de No Utilización del Plastico
     and t.tar_Activa = 'S'
     --and greatest(nvl(trunc(fec_ult_mov_pos),to_date('01010001','ddmmyyyy')),nvl(trunc(fec_ult_mov_atm),to_date('01010001','ddmmyyyy'))) > ADD_MONTHS(t.fec_vencimiento, -4)
     and greatest(nvl(trunc(fec_ult_mov_pos),to_date('01010001','ddmmyyyy')),nvl(trunc(fec_ult_mov_atm),to_date('01010001','ddmmyyyy'))) >  last_day(ADD_MONTHS(trunc(sysdate), -4)) 
     --información de ingreso
     
     
   
   union
  select t.nro_cuenta , t.adherente,
         nvl(t.cod_ofi_origen,g.cod_oficina ), t.embozado,
         fec_vencimiento,
         t.fec_ingreso, t.cod_persona, t.nro_emision,
         g.cod_modulo , t.tip_envio,t.referencia, t.cod_ent_procesadora, v.cod_moneda, nro_bin,
         tip_tar_debito, (select sum(t.mto_ingreso)
                           from CR_INF_LABORALES T
                          where T.ACTUAL = 'S'
                            --and T.MTO_FIJO = 'S'
                            and t.cod_persona = l.cod_persona) mto_ingreso, v.cod_modalidad
         --fug_tie_mov_extranjero(v.nro_cuenta, v.cod_modalidad,-12) mov_ext
    from ah_tar_debitos t, ah_cta_vistas v , ge_cta_clientes g , ge_clientes l
   where t.nro_cuenta  = g.nro_cuenta
     and t.nro_cuenta  = v.nro_cuenta
     and g.cod_persona = l.cod_persona
     and t.cod_persona = g.cod_persona--Ajuste para que no duplique (Cuando tiene varios firmantes)
     and v.estado in('N','A','S')
     and to_number(to_char(t.fec_vencimiento, 'yyyymm')) = to_number(p_ano||lpad(to_char(p_mes),2,'0'))
     and t.cod_est_solicitud not in(16, 17) --- No toma las anuladas ni las de No Utilización del Plastico
     and t.tar_Activa = 'S'
     --and greatest(nvl(trunc(fec_ult_mov_pos),to_date('01010001','ddmmyyyy')),nvl(trunc(fec_ult_mov_atm),to_date('01010001','ddmmyyyy'))) > ADD_MONTHS(t.fec_vencimiento, -4)
     and greatest(nvl(trunc(fec_ult_mov_pos),to_date('01010001','ddmmyyyy')),nvl(trunc(fec_ult_mov_atm),to_date('01010001','ddmmyyyy'))) >  last_day(ADD_MONTHS(trunc(sysdate), -4))
     --información de ingreso
     
   order by 5,12,1;
BEGIN
  Begin PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:=1;end;
  
  -- Obtengo el nro de bin actual de la procesadora 
  if v_hab_tdd_mastercard ='S' then -- si ya esta habilitado Mastercard se renovaran como MC
     v_nro_bin_procesadora := v_nro_bin_mastercard;
  else 
     v_nro_bin_procesadora := v_nro_bin_visa;  
  end if;
  --    
  v_tot_renovadas := 0;
  
   --búsqueda de tip tdd infonet normal
   begin
      select T.VAL_MINIMO
        into v_tip_tdd_infonet
        from BA_COD_REFERENCIAS T
       where T.DOMINIO = 'TIP_TAR_DEBITO'
         and T.ABREVIATURA = fug_obt_pardinamico('TIP_TDD_RENOVACION');
   exception
      when others then
         RAISE_APPLICATION_ERROR(-20000,'Error al obtener datos de tipo de tarjeta INFONET/VISA. ' || sqlerrm);
   end;

  v_lugar := 'Procesando Renovaciones.';
  for reg in vencidas loop
      
      -- 27/01/10 : Segun lo conversado con A.B. , sin el tipo es del bin anterior se reneva como clasica
      -- sino se hereda el tipo de la tarjeta a renovar
      v_tip_tar_deb := reg.tip_tar_debito;
      if  nvl(v_tip_tar_Deb,'B') = 'B' then   --Bin anterior
         v_tip_tar_deb :=  'M';
      end if;
      
      
      
      if reg.nro_bin != v_nro_bin_tdd_infonet then --Solo se calcula cuando el tipo de tarjeta es VISA
      -- NUEVO BIN --
      --si el ingreso del cliente es >= 5.000.000 se le asigna VISA sino Infonet
      --si el cliente no registra operaciones en el exterior hasta hace 12 mesess
          v_tie_mov_ext := fug_tie_mov_extranjero(reg.nro_cuenta, reg.cod_modalidad, v_plz_mes_mov_exterior * -1);
          if nvl(reg.mto_ingreso,0) < v_mto_ref_tdd_infonet and v_tie_mov_ext = 'N' then
            v_nro_bin_procesadora := v_nro_bin_tdd_infonet;
            if reg.tip_tar_debito in ('M','C') THEN -- Mastercard o Visa
               v_tip_tar_deb := v_tip_tdd_infonet;--asignar infonet normal
            elsif reg.tip_tar_debito = 'N' THEN --Visa nómina
               v_tip_tar_deb := 'I';    --asignar infonent nómina
            end if;
          else
            -- si el bin de visa ya esta configurado en el PD, significa que ya no puedo renovar como VISA 
            -- se debe renovar como mastercard si ya esta habilitado el alta
            if reg.nro_bin = nvl(fug_obt_pardinamico('VAL_BIN_SOL_TDD_VISA'),0) and
              v_hab_tdd_mastercard ='S' then
                v_tip_tar_deb := 'M';
                v_nro_bin_procesadora :=  v_nro_bin_mastercard;
            else  
                v_tip_tar_deb := reg.tip_tar_debito;
                v_nro_bin_procesadora := reg.nro_bin;
            end if;    
          end if;
      else
         v_tip_tar_deb := reg.tip_tar_debito;
         v_nro_bin_procesadora := reg.nro_bin;
      
      end if;
      
      
      --- Si el nro. de bin es igual al bin actual de la procesadora entonces se toma como una renovacion
      if  nvl(reg.nro_bin,0) = nvl(v_nro_bin_procesadora,0) then
         v_nueva_emision := lpad(to_char(to_number(reg.nro_emision)+1), 2, '0');
         v_nuevo_adherente := reg.adherente;
         v_renovacion      := 'S';
      else  -- si el bin es el bin anterior entonces la renovacion sale como una nueva emision
         v_nuevo_adherente := '00';
         v_nueva_emision   := '01';
         v_renovacion      := 'N';
      end if;
      v_fec_vencimiento := last_day(add_months(reg.fec_vencimiento, (nvl(v_anio_vencimiento,4)*12)));
      --Insertar en ah_Tar_debitos la renovacion
      v_tot_renovadas := v_tot_renovadas + 1 ;
      BEGIN
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
	      cod_ent_procesadora, renovacion,nro_bin,
	      tip_tar_debito)
	    values (reg.nro_cuenta,
	            'S',
	            Decode(reg.cod_modulo, 3, v_fec_ahorros, 4, v_fec_ctacte),
	            reg.cod_persona,
	            reg.embozado,
	            user,
	            Decode(reg.cod_modulo, 3, v_fec_ahorros, 4, v_fec_ahorros),
	            v_nuevo_adherente,
	            v_Nueva_Emision,
	            '2', -- A aprobar por el operativo
	            null,
	            reg.cod_ofi_origen,
	            null,
	            null,
	            reg.fec_ingreso,
	            v_fec_vencimiento,
	            null,
	            null,
	            null,
	            null,
	            null,
	            v_fec_actual,
	            reg.tip_envio,
	            reg.referencia,
	            v_cod_procesadora, v_renovacion, v_nro_bin_procesadora, v_tip_tar_deb);
       EXCEPTION --DYDMR-6822
         WHEN DUP_VAL_ON_INDEX THEN
           v_err_ctas := v_err_ctas|| ' - '||reg.nro_cuenta;
       END;              
	    --
	    -- Al número de emisión anterior la cancela y le inserta la fecha de cancelacion
	    --
	   --v_lugar := 'Actualizando AH_TAR_DEBITOS RENOVADAS ...';

	    update AH_TAR_DEBITOS
	       set cod_est_solicitud = '16',
	           fec_cancelacion = trunc(v_fec_actual),
             cod_causa = v_cod_causa --DYDMR-7138
	     where nro_cuenta  = reg.nro_cuenta
	       and adherente   = reg.adherente
	       and nro_emision = reg.nro_emision
         and nvl(nro_bin,v_nro_bin_procesadora) = nvl(reg.nro_bin,v_nro_bin_procesadora)
	       and cod_ent_procesadora = v_cod_procesadora;
      if SQL%NOTFOUND then --DYDMR-6822
        v_err_ctas := v_err_ctas|| ' - '||reg.nro_cuenta;
      end if;
  End Loop;

  v_lugar := 'Insertando en AH_TAR_DEB_ENVIOS.';
  if v_tot_renovadas > 0 then
      begin
       insert into AH_TAR_DEB_ENVIOS(
                      FEC_PROCESO,
                      ESTADO,
                      CAN_TAR_RENOVADAS,
                      COD_ENT_PROCESADORA)
               values (v_fec_actual,
                       'G',
                       v_tot_renovadas,
                       v_cod_procesadora);
      Exception
        When Others then
          raise_application_error(20001,'ERROR AL INSERTAR AH_TAR_DEB_ENVIOS '||SQLERRM);
      end;
    end if;
    --DYDMR-6822
    P_MSG := v_err_ctas;

end PRA_TAR_DEB_RENOVACION;
/

