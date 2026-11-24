CREATE OR REPLACE TRIGGER IT.tb_ba_personas
  BEFORE DELETE OR INSERT OR UPDATE ON "IT"."BA_PERSONAS"
  FOR EACH ROW

DECLARE

  V_VER_PERSONA     VARCHAR2(01);
  v_mensaje         varchar2(100);
  v_vto_obligatorio ba_tip_documentos.vto_obligatorio%TYPE;
  v_fec_actual      DATE;
  v_abreviatura     ba_tip_documentos.abreviatura%TYPE;
  v_dir_correo      ba_personas.dir_correo%TYPE;
  v_nro_cuenta      ge_cuentas.nro_cuenta%TYPE;
  v_nro_cta_gp      ge_cuentas.nro_cuenta%TYPE;

/* Valida tipo de persona */
FUNCTION LF_VAL_TIPO_PERSONA
 (P_TIPO IN BA_TIP_DOCUMENTOS.TIP_PERSONA%TYPE
 ,P_COD_TIP_DOCUMENTO IN BA_TIP_DOCUMENTOS.COD_TIP_DOCUMENTO%TYPE
 )
 RETURN BOOLEAN;

/* Valida tipo de persona */
FUNCTION LF_VAL_TIPO_PERSONA
 (P_TIPO IN BA_TIP_DOCUMENTOS.TIP_PERSONA%TYPE
 ,P_COD_TIP_DOCUMENTO IN BA_TIP_DOCUMENTOS.COD_TIP_DOCUMENTO%TYPE
 )
 RETURN BOOLEAN
 IS

V_TIPO_PERSONA BA_TIP_DOCUMENTOS.TIP_PERSONA%TYPE;
begin
      select tip_persona
      into v_tipo_persona
      from BA_TIP_DOCUMENTOS
      where cod_tip_documento = p_cod_tip_documento;
      if  (v_tipo_persona = p_tipo) or
          (v_tipo_persona is null )  or
          (v_tipo_persona = 'A'   ) then
          return TRUE;
      else
          return FALSE;
      end if;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Tipo Doc: '||to_char(p_cod_tip_documento)||' no registrado');
   when others then
      null;
end;

FUNCTION LF_VAL_TIP_DOC_ACTIVO
 (P_COD_TIP_DOCUMENTO IN BA_TIP_DOCUMENTOS.COD_TIP_DOCUMENTO%TYPE
 )
 RETURN BOOLEAN
 IS
 v_estado ba_tip_documentos.estado%type;
begin
      select estado, vto_obligatorio, abreviatura
      into v_estado, v_vto_obligatorio, v_abreviatura
      from BA_TIP_DOCUMENTOS
      where cod_tip_documento = p_cod_tip_documento;

      if  (nvl(v_estado,'A') != 'I'   ) then
          return TRUE;
      else
          return FALSE;
      end if;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Tipo Doc: '||to_char(p_cod_tip_documento)||' no registrado');
   when others then
      null;
end;

function lf_tiene_circuito(p_cod_persona ba_personas.cod_persona%type) return boolean is
  v_existe varchar2(1);
begin
  select 'S'
  into v_existe
  from wf_circuitos c
  where c.referencia = p_cod_persona
  and c.cod_tip_circuito in (7,5,38,44)
  and c.estado = 'E'
  and rownum = 1;
  return true;
  exception
    when no_data_found then
      return false;
    when others then 
      return false;
end;
  
BEGIN
   v_fec_actual := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
if /*user <> 'IT' and*/ nvl(PAE_CNF.G_PROGRAMA,'x') NOT IN ('GMPROARC','TPRECTAR','GMANTICI','PAG_SAD') then
   -- Solo para evitar que los traspasos del APPX vuelvan al appx y que las personas
   -- ingresadas a traves de la OFAC no se traspasen al APPX.
   if inserting then
      if :new.est_verificacion in ('S','V') then
         :new.fec_verificacion    := v_fec_actual;
         :new.cod_usu_verificador := user;
      end if;
      if  lf_val_tipo_persona(:new.tipo,:new.cod_tip_documento)=false then
          raise_application_error(-20000,
          'Tipo de documento no corresponde a tipo persona');
      end if;
      if not fue_val_tip_doc(:new.cod_tip_documento,:new.nro_documento,v_mensaje,:new.tipo) then
        raise_application_error(-20000,v_mensaje);
      end if;
      if not lf_val_tip_doc_activo(:new.cod_tip_documento) then
         raise_application_error(-20000,'Tipo de Documento Inactivo');
      end if;
      -- Validaciones del vencimiento del documento
      if nvl(v_vto_obligatorio,'N') = 'S' Then
         If :new.fec_vto_documento is null Then
            raise_application_error(-20000,'Ingrese el Vencimiento del Documento');
         End If;
      end if;
      if :new.fec_vto_documento is not null and
         fue_obt_des_refcodes('USU_ALT_PERSONA', user) <> user then
         if :new.fec_vto_documento < v_fec_actual then
            raise_application_error(-20000,'Documento vencido no puede ser ingresado');
         elsif :new.fec_vto_documento > v_fec_actual + (20 * 365) then
            raise_application_error(-20022,'Vencimiento del documento invalido');
         end if;
      end if;  -- Hasta aqui Validaciones del vencimiento del documento
      -- para persona jurídica es obligatorio el CUIT
   -- Comentado p/ BB
   /*   if :new.tipo = 'J' and v_abreviatura <> 'CUIT' then
         raise_application_error(-20000,'Documento principal de Persona Jurídica debe ser CUIT');
      end if;
      --validar dígitos del cuil y cuit
      if v_abreviatura in ('CUIL','CUIT') then
         if fue_val_dig_cuil(:new.nro_documento) then
            null;
         end if;
      end if;*/
   elsif updating then
      if :new.est_verificacion in ('S','V') and
         :new.est_verificacion <> :old.est_verificacion then
         :new.fec_verificacion    := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
         :new.cod_usu_verificador := user;
      end if;
      if  lf_val_tipo_persona(:new.tipo,:new.cod_tip_documento)=false then
          raise_application_error(-20000,
          'Tipo de documento no corresponde a tipo persona');
      end if;
      --- verifico si existe verificacion de personas
      v_ver_persona := fug_obt_pardinamico('VER_PERSONA');
      If (:old.nro_documento <> :new.nro_documento
       or :old.nom_completo <> :new.nom_completo
       or :old.cod_tip_documento <> :new.cod_tip_documento)
      and v_ver_persona = 'S'
      and :old.est_verificacion = :new.est_verificacion
      and :new.est_verificacion = 'V'  then
         :new.est_verificacion := 'N' ;
      End if;
      -- Validar formato del documento
      If :old.nro_documento <> :new.nro_documento then
        if not fue_val_tip_doc(:new.cod_tip_documento,:new.nro_documento,v_mensaje) then
           raise_application_error(-20000,v_mensaje);
        end if;
      End if;
      -- solo si se cambio algo de esto
      if :new.nom_completo <> :old.nom_completo or
         :new.cod_tip_documento <> :old.cod_tip_documento or
         :new.nro_documento <> :old.nro_documento or
         :new.fec_verificacion <> :old.fec_verificacion or
         :new.fec_vto_documento <> :old.fec_vto_documento then
         --
          if not lf_val_tip_doc_activo(:new.cod_tip_documento) then
             raise_application_error(-20000,'Tipo de Documento Inactivo');
          end if;
          -- Validaciones del vencimiento del documento
          if nvl(v_vto_obligatorio,'N') = 'S' Then
             If :new.fec_vto_documento is null Then
                raise_application_error(-20000,'Ingrese el Vencimiento del Documento');
             End If;
          end if;
          /* DA-9147
             En el caso de que se cumpla ambas condiciones, NO quiero que valide la
             Fecha de vencimiento de la cedula
          */
          if not(nvl(PAE_CNF.G_PROGRAMA, 'X') = 'WMSEGUIM' and lf_tiene_circuito(:new.cod_persona))  then
             if :new.fec_vto_documento is not null and
                fue_obt_des_refcodes('USU_ALT_PERSONA', user) <> user then   
                if :new.fec_vto_documento < v_fec_actual then
                   raise_application_error(-20000,'Documento vencido no puede ser ingresado');
                elsif :new.fec_vto_documento > v_fec_actual + (20 * 365) then
                   raise_application_error(-20000,'Vencimiento del documento invalido');
                end if;
             end if;  
          end if; -- Hasta aqui Validaciones del vencimiento del documento
          --validar dígitos del cuil y cuit
          if v_abreviatura in ('CUIL','CUIT') then
             if fue_val_dig_cuil(:new.nro_documento) then
                null;
             end if;
          end if;

      End if;
   end if;
end if;
   --DYDMR-2480 ITGF - Nombre de Clientes con caracteres especiales - SC 21234
   if inserting or updating then
      if :new.nom_completo <> :old.nom_completo then
         :new.nom_completo := replace(replace(:new.nom_completo, chr(10), ''), chr(13), '');
      end if;
   end if;
   if inserting then
     if :new.tip_iva is null then
       if :new.tipo = 'F' then
         :new.tip_iva := 'NC';
       elsif :new.tipo = 'J' then
         :new.tip_iva := 'CO';
       end if;
     end if;
   end if;
END;
/

