CREATE OR REPLACE PROCEDURE IT.PRA_VER_PRO_REN_MASIVO(P_TIP_PROCESO IN VARCHAR2,
                                                   P_MSJ_PROCESO OUT VARCHAR2
                                                   ) is

  --Variables--
  v_fecha date;
  v_hora varchar2(8);
  v_est_lote varchar2(1);
  v_est_registro varchar2(1);
  v_cod_modalidad ah_cta_vistas.cod_modalidad%type;
  v_msj_det_error varchar2(4000);
  v_msj_det_error_aux varchar2(4000);
  v_fec_vencimiento date;
  v_exi_persona varchar2(1);
  v_exi_adherente varchar2(1);
  v_tar_activa varchar2(1);
  v_tar_nro_emision ah_tar_debitos.nro_emision%type;
  v_tip_tar_ren ah_tar_debitos.tip_tar_debito%type;
  v_nro_bin_ren ah_tar_debitos.nro_bin%type;
  v_nro_lote number(6);
  v_can_reg_lote number(6);
  v_can_reg_error number(6);
  --v_ret_carro varchar2(500) := chr(13);
  v_ret_carro varchar2(500) := '**';
  v_ide_registro ah_tar_deb_masivo_tmp.ide_reg_lote%type;
  v_cod_procesadora ah_tar_debitos.cod_ent_procesadora%type := fug_obt_pardinamico('COD_PRO_BANCARD');
  v_can_pro_lote number(6);
  v_can_nor_lote number(6);
  v_can_err_lote number(6);
  v_mensaje varchar2(4000);
  v_est_cuenta ge_est_cuentas.estado%type;
  V_LUGAR VARCHAR2(4000);
  v_nro_cuenta ah_tar_cta_ficticias.nro_cta_cliente%type;

  -------
  --v_nro_bin_tdd_infonet ah_tar_debitos.nro_bin%TYPE := fug_obt_parentes(v_cod_pro_bancard, 'NRO_BIN_TDD_INFONET');--TDD NUEVO BIN
  --v_nro_bin_tdd_visa    ah_tar_debitos.nro_bin%TYPE := fug_obt_parentes(v_cod_pro_bancard, 'NRO_BIN_TAR_DEBITO');-- TDD BIN VISA
  --v_tip_tar_debito ah_tar_debitos.tip_tar_debito%type := 'N'; --por defecto dejanmos en VISA
  --v_tip_tar_deb_nomina ah_tar_debitos.tip_tar_debito%type := 'I';--default NOMINA
  --v_tip_tar_deb_VISA ah_tar_debitos.tip_tar_debito%type := 'N';--default NOMINA

  --Cursores--
  cursor c_ren_tar_deb_masivo is

      select t.*, t.rowid registro
      from AH_TAR_DEB_MASIVO_TMP t
     where t.usu_insercion = user
     order by t.rowid;
begin
  V_LUGAR := 'Inicio de variables';
  --Variables generales--
  v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(3);
  v_hora  := to_char(sysdate,'HH24:MI:SS');
  v_can_reg_error := 0;
  v_est_lote := 'P';


  --Verificar datos importados--
  v_can_reg_lote := 0;
  for det in c_ren_tar_deb_masivo loop
     V_LUGAR := 'Inicio de variables dentro del cursor de tarjetas';
      --Inicializar variables--
      v_est_registro := 'N'; --Insertado--
      v_cod_modalidad := null;
      v_msj_det_error := null;
      v_fec_vencimiento := null;
      v_exi_persona := null;
      v_exi_adherente := null;
      v_tip_tar_ren := null;
      v_ide_registro := null;
      v_est_cuenta := null;
      v_can_reg_lote := nvl(v_can_reg_lote,0) + 1;
      --v_tar_nro_emision :=null;
      
      
      --Validacion de Tipo de Tarjeta--
      v_msj_det_error_aux := null;
      begin
       select a.val_minimo,
              fug_obt_parentes(v_cod_procesadora, a.val_maximo)
         into v_tip_tar_ren, v_nro_bin_ren
         from ba_cod_referencias a
        where a.dominio = 'TIP_TAR_DEBITO'
          and a.abreviatura = det.tip_tarjeta;
      exception
        when no_data_found then
           v_msj_det_error_aux := 'Tipo de TD '||det.Tip_Tarjeta||
           ' no existe.'||v_ret_carro;
        when too_many_rows then
           v_msj_det_error_aux := 'Tipo de TD '||det.Tip_Tarjeta||
           ' duplicado en referencias.'||v_ret_carro;
        when others then
           v_msj_det_error_aux := 'Tipo de TD '||det.Tip_Tarjeta||
           ' con error.'||sqlerrm||v_ret_carro;
      end;
      if v_msj_det_error_aux is not null then
         v_msj_det_error := substr(v_msj_det_error||v_msj_det_error_aux,1,4000);
      end if;
      
      /* DYDMR-17003 Activación e Inactivación masiva de TD MASTERCARD*/
      if p_tip_proceso in ('T', 'I') then
        if v_tip_tar_ren in ('M','P') then --Sí es Mastercard viene la cuenta ficticia-- BSEVOCORE-1029
          v_nro_cuenta := fua_obt_cta_cliente(det.nro_cuenta,v_nro_bin_ren);
        else
          v_nro_cuenta := det.nro_cuenta;
        end if;
      else 
        v_nro_cuenta := det.nro_cuenta;
      end if;
      /*FIN DYDMR-17003*/

      --Validacion de cuenta--
      v_msj_det_error_aux := null;
      begin
        select x.estado, x.cod_modalidad
          into v_est_cuenta, v_cod_modalidad
          from ge_cuentas x
         where x.nro_cuenta = v_nro_cuenta;
      exception
         when no_data_found then
              v_msj_det_error_aux := 'Cta. no existe '||v_nro_cuenta||
              v_ret_carro;
         when others then
              v_msj_det_error_aux := substr('Cta. '||v_nro_cuenta||
              ' con error: '||sqlerrm,1,2000)||v_ret_carro;
      end;
      if v_msj_det_error_aux is not null then
         v_msj_det_error := substr(v_msj_det_error_aux,1,4000);
      end if;
      --Verificacion de estado de cuenta--
      v_msj_det_error_aux := null;
      if nvl(v_est_cuenta,'X') = 'C' then --Cta. cancelada--
         v_msj_det_error_aux := 'Cta. Cancelada '||v_nro_cuenta||
              v_ret_carro;
      end if;
      if v_msj_det_error_aux is not null then
         v_msj_det_error := substr(v_msj_det_error_aux,1,4000);
      end if;

      
      /* Add validacion en Proyecto SDBIN8TDD-1 Si es un proceso de Alta y corresponde a un BIN de Visa  entonces debe dar error
       EL BIN a restringir se configura en el Parametro Dinamico VAL_BIN_SOL_TDD_VISA*/
      if P_TIP_PROCESO ='A' and   
        v_nro_bin_ren = NVL(fug_obt_pardinamico('VAL_BIN_SOL_TDD_VISA'),0) THEN
        v_msj_det_error := substr(v_msj_det_error||' Operacion No Permitida para el BIN '||v_nro_bin_ren,1,4000);
      end if;
      --  
      --Validacion de Nro. de BIN--
      v_msj_det_error_aux := null;
      if v_nro_bin_ren is null then
         v_msj_det_error_aux := 'Nro Bin nulo. Verificar referencia TIP_TAR_DEBITO y parametro de Bin asociado a Tipo de TD';
      end if;
      if v_msj_det_error_aux is not null then
         v_msj_det_error := substr(v_msj_det_error||v_msj_det_error_aux,1,4000);
      end if;

      --Validacion de fecha de vencimiento--
      v_msj_det_error_aux := null;
      begin
        select last_day(to_date('01/'||det.fec_ven_carga,'DD/MM/YYYY'))
          into v_fec_vencimiento
          from dual;
      exception
         when others then
           v_fec_vencimiento := to_date(null);
           v_msj_det_error_aux := 'Fecha de Venc. '||det.fec_ven_carga||
           ' incorrecta.'||v_ret_carro;
      end;
      if v_msj_det_error_aux is not null then
         v_msj_det_error := substr(v_msj_det_error||v_msj_det_error_aux,1,4000);
      end if;
      --Validar que la fecha de venc no sea menor--
      v_msj_det_error_aux := null;
      if v_fec_vencimiento <= v_fecha then
         v_msj_det_error_aux := 'Fecha de Venc. '||to_char(v_fec_vencimiento,'dd/mm/yyyy')||
           ' menor o igual a fecha actual '||to_char(v_fecha,'dd/mm/yyyy')||v_ret_carro;
      end if;
      if v_msj_det_error_aux is not null then
         v_msj_det_error := substr(v_msj_det_error||v_msj_det_error_aux,1,4000);
      end if;


      --Validacion de Cod. Persona--
      v_msj_det_error_aux := null;
      select decode(nvl(count(*),0),0,'N','S')
        into v_exi_persona
        from ba_personas x
       where x.cod_persona = det.cod_persona;
      if nvl(v_exi_persona,'N') = 'N' then
         v_msj_det_error_aux := 'Cliente no existe '||det.cod_persona||
         v_ret_carro;
      end if;
      if v_msj_det_error_aux is not null then
         v_msj_det_error := substr(v_msj_det_error||v_msj_det_error_aux,1,4000);
      end if;

      --Valicacion de Adherente--
      v_msj_det_error_aux := null;
      select decode(nvl(count(*),0),0,'N','S')
        into v_exi_adherente
        from ah_tar_debitos x
       where x.nro_cuenta = v_nro_cuenta
         and x.cod_persona = det.cod_persona
         and x.adherente = det.adherente;
        -- AND x.renovacion = 'S';--Condicionar que solo se aplique esta verificación a los proceso de renovación solamente - DYDMR-15288
      if nvl(v_exi_adherente,'N') = 'N' then
         v_msj_det_error_aux := 'Adherente '||det.adherente||'-'||det.cod_persona||'-'||
           v_nro_cuenta||' no existe.'||v_ret_carro;
      end if;
      if v_msj_det_error_aux is not null then
         v_msj_det_error := substr(v_msj_det_error||v_msj_det_error_aux,1,4000);
      end if;

      --Validacion de modalidad--
      v_msj_det_error_aux := null;
      if v_cod_modalidad not in (31,41) then
         v_msj_det_error := 'Modalidad '||to_char(v_cod_modalidad)||
         ' incorrecta para TD.'||v_ret_carro;
      end if;
      if v_msj_det_error_aux is not null then
         v_msj_det_error := substr(v_msj_det_error||v_msj_det_error_aux,1,4000);
      end if;
      
      --validación de tarjeta para activar O DESACTIVAR
      if P_TIP_PROCESO in ('T','I') THEN --(ACTIVAR / INACTIVAR)
          v_msj_det_error_aux := null;
          
          begin
            select X.TAR_ACTIVA/*, x.nro_emision*/
              into v_tar_activa/*, v_tar_nro_emision*/
              from ah_tar_debitos x
             where x.nro_cuenta = v_nro_cuenta
               and x.cod_persona = det.cod_persona
               and x.adherente = det.adherente
               AND X.NRO_EMISION = DET.NRO_EMISION
               and x.nro_bin = v_nro_bin_ren;--CORRECCIÓN
               /*AND X.NRO_EMISION = (select max(a.nro_emision) 
                                    from ah_tar_debitos a 
                                    where a.nro_cuenta = det.nro_cuenta
                                    and   a.cod_persona = det.cod_persona
                                    and   a.adherente = det.adherente);*/
          exception 
              when no_data_found then
             -- v_msj_det_error_aux := 'NO se encuentra la tarjeta a verificar';
              v_msj_det_error_aux := 'Adherente '||det.adherente||'-'||det.cod_persona||'-'||
                 v_nro_cuenta||'-Nro Emisión: '||det.nro_emision||' no se encuentra.'||v_ret_carro;
              when others then
              v_msj_det_error_aux := 'Error al buscar TDD: '||sqlerrm;
          end;
            if P_TIP_PROCESO = 'T' then --(activar)
              if nvl(v_tar_activa,'N') = 'S' then
                 v_msj_det_error_aux := 'Adherente '||det.adherente||'-'||det.cod_persona||'-'||
                 v_nro_cuenta||'-Nro Emisión: '||det.nro_emision||' ya ESTÁ ACTIVA.'||v_ret_carro;
              end if;
            elsif P_TIP_PROCESO = 'I' THEN --(inactivar)
              if nvl(v_tar_activa,'N') = 'N' then
                 v_msj_det_error_aux := 'Adherente '||det.adherente||'-'||det.cod_persona||'-'||
                 v_nro_cuenta||'-Nro Emisión: '||det.nro_emision||' ya ESTÁ DESACTIVADA.'||v_ret_carro;
               end if;
            end if;
            
            if v_msj_det_error_aux is not null then
               v_msj_det_error := substr(v_msj_det_error||v_msj_det_error_aux,1,4000);
            end if;
            
          
       END IF;
    
      
     

      --Actualizar el registro--
      if v_msj_det_error is not null then
         v_est_registro := 'E';
         v_can_reg_error := nvl(v_can_reg_error,0) + 1;
         v_msj_det_error := substr('Validac.-Nro.Reg.:'||to_char(v_can_reg_lote)||v_ret_carro||v_msj_det_error,1,4000);
      end if;
      --Obtener el Identificador del Registro--
      --Traer Nro. de Lote--
      SELECT S_IDE_REG_PRO_TARDEB.NEXTVAL
        INTO V_IDE_REGISTRO
        FROM DUAL;

      update ah_tar_deb_masivo_tmp y
         set y.fec_vencimiento = v_fec_vencimiento,
             y.est_registro = v_est_registro,
             y.msj_registro = v_msj_det_error,
             y.nro_registro = v_can_reg_lote,
             y.ide_reg_lote = v_ide_registro,
             y.tip_tar_debito = v_tip_tar_ren,
             y.nro_bin = v_nro_bin_ren,
             y.tip_proceso = p_tip_proceso
            -- y.nro_emision = v_tar_nro_emision
       where y.rowid = det.registro;
  end loop;

  --Traer Nro. de Lote--
  SELECT S_NRO_LOT_PRO_TARDEB.NEXTVAL
    INTO V_NRO_LOTE
    FROM DUAL;
  if v_can_reg_error = v_can_reg_lote then
     v_est_lote := 'E';
  end if;
  --Actualizar nro de Lote--
  update ah_tar_deb_masivo_tmp y
     set y.nro_lote = v_nro_lote,
         y.est_lote = v_est_lote, --Procesado--
         y.fec_pro_lote = v_fecha,
         y.hor_pro_lote = v_hora
   where y.usu_insercion = user;

  --Insertar tabla normal--
  insert into AH_TAR_DEB_MASIVO
  select x.*
    from ah_tar_deb_masivo_tmp x
   where x.nro_lote = v_nro_lote;

  --Llamada a proceso de Tarjeta de Debito;
  if v_est_lote <> 'E' then-- SI NO HAY ERROR EN EL LOTE SE PROCESA
    IF P_TIP_PROCESO IN ('A','R') THEN--ALTA Y RENOVACIÓN 
       pra_tar_deb_ren_masivo(v_nro_lote);
    ELSIF p_tip_proceso = 'P' then --, P-REEMPLAZO
      pra_tar_deb_rmp_masivo(v_nro_lote); 
    END IF;
  end if;

  --Cargar Mensaje resultado del Proceso--
  --v_nro_lote := 7;
  v_can_pro_lote := 0;
  v_can_nor_lote := 0;
  v_can_err_lote := 0;
  select nvl(count(*),0),
         sum(decode(x.est_registro,'N',1,0)),
         sum(decode(x.est_registro,'E',1,0))
    into v_can_pro_lote, v_can_nor_lote, v_can_err_lote
    from AH_TAR_DEB_MASIVO x
   where x.nro_lote = v_nro_lote;

  --Enviar el email del resultado--
  pra_env_mai_pro_lote(v_nro_lote,v_mensaje);

  --Cargar mensaje de retorno--
  P_MSJ_PROCESO := v_mensaje;
exception
  when Others then
       raise_application_error(-20001,'Error en pra_ver_pro_ren_masivo: '||SQLERRM);
end;
/

