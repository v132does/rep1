CREATE OR REPLACE TRIGGER IT.TB_BA_PER_DOCUMENTOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON IT.BA_PER_DOCUMENTOS
 FOR EACH ROW


DECLARE

V_VER_PERSONA VARCHAR2(01);
v_mensaje varchar2(100);
v_vto_obligatorio ba_tip_documentos.vto_obligatorio%type;
v_fec_actual date;
v_tipo ba_personas.tipo%type;
v_sexo ba_per_fisicas.cod_sexo%type;
v_abreviatura ba_tip_documentos.abreviatura%type;
v_nro_documento ba_personas.nro_documento%type;
v_tip_documento ba_personas.cod_tip_documento%type;
v_desc_tip_documento ba_tip_documentos.descripcion%type;
v_existe_tipo number;
v_existe_nro  number;
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
      raise_application_error(-20000, 'Tipo Doc: '||to_char(p_cod_tip_documento)||' no registrado');
   when others then
      null;
end;

BEGIN
   if inserting or updating then
     begin
        select count(*)
        into v_existe_tipo
        from ba_per_documentos a
        where a.cod_persona = :new.cod_persona
        and a.cod_tip_documento = :new.cod_tip_documento;
     end;
     begin
        select count(*)
        into v_existe_nro
        from ba_per_documentos a
        where a.cod_persona = :new.cod_persona
        and a.nro_documento = :new.nro_documento;
     end;
     begin
        select a.descripcion
        into v_desc_tip_documento
        from ba_tip_documentos a
        where a.cod_tip_documento = :new.cod_tip_documento;
        exception
          when others then
            v_desc_tip_documento := null;
     end;
     begin
       select tipo, nro_documento, cod_tip_documento
         into v_tipo, v_nro_documento, v_tip_documento
         from ba_personas
        where cod_persona = :new.cod_persona;
        if v_tipo = 'F' then
          select cod_sexo
            into v_sexo
            from ba_per_fisicas
           where cod_persona = :new.cod_persona;
        end if;
     exception
       when others then
         null;     
     end;

      --se debe validar que no se puede ingresar tipo y numero duplicado para la misma persona
      if (v_tip_documento = :new.cod_tip_documento or nvl(v_existe_tipo,0) <> 0) then
         raise_application_error(-20000, 'Tipo Doc: '||to_char(v_desc_tip_documento)||' La persona ya tiene registrado este documento.');
      end if;
      if (v_nro_documento = :new.nro_documento or nvl(v_existe_nro,0) <> 0) then
         raise_application_error(-20000, 'Nro. Doc: '||to_char(v_nro_documento)||' Este número de documento ya existe para la persona.');
      end if;           
   end if;
   
   if inserting then
      if not fue_val_tip_doc(:new.cod_tip_documento,:new.nro_documento,v_mensaje, v_tipo, v_sexo) then
        raise_application_error(-20000,v_mensaje);
      end if;
      --validar si está activo
      if not lf_val_tip_doc_activo(:new.cod_tip_documento) then
         raise_application_error(-20000,'Tipo de Documento Inactivo');
      end if;
      -- Validaciones del vencimiento del documento
      if nvl(v_vto_obligatorio,'N') = 'S' Then
         If :new.fec_vto_documento is null Then
            raise_application_error(-20000,'Ingrese el Vencimiento del Documento');
         End If;
      end if;
      if :new.fec_vto_documento is not null then
         if :new.fec_vto_documento < v_fec_actual then
            raise_application_error(-20000,'Documento vencido no puede ser ingresado');
         elsif :new.fec_vto_documento > v_fec_actual + (20 * 365) then
            raise_application_error(-20000,'Vencimiento del documento invalido');
         end if;
      end if;
      --si es jurídica el CUIT debe ser principal, no puede ser adicional
      if v_tipo = 'J' and v_abreviatura = 'CUIT' then
         raise_application_error(20000,'Persona Jurídica debe tener CUIT como documento principal, no adicional');
      end if;
      --si es cuil validar contra el nro de documento
      if v_abreviatura = 'CUIL' then
         if fue_val_doc_cuil(:new.nro_documento, v_nro_documento) then
            null;
         end if;
      /*elsif v_abreviatura = 'DNI' then -- si es dni validar contra el cuil
         if v_nro_documento*/
      end if;
      --validar dígitos del cuil y cuit
      if v_abreviatura in ('CUIL','CUIT') then
         if fue_val_dig_cuil(:new.nro_documento) then
            null;
         end if;
      end if;
   elsif updating then
      -- Validar formato del documento
      If :old.nro_documento <> :new.nro_documento then
        if not fue_val_tip_doc(:new.cod_tip_documento,:new.nro_documento,v_mensaje, v_tipo, v_sexo) then
           raise_application_error(-20000,v_mensaje);
        end if;
      End if;
      -- solo si se cambio algo de esto
      if :new.nro_documento <> :old.nro_documento or
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
          if :new.fec_vto_documento is not null then
             if :new.fec_vto_documento < v_fec_actual then
                raise_application_error(-20000,'Documento vencido no puede ser ingresado');
             elsif :new.fec_vto_documento > v_fec_actual + (20 * 365) then
                raise_application_error(-20000,'Vencimiento del documento invalido');
             end if;
          end if;
          -- Hasta aqui Validaciones del vencimiento del documento
      End if;
      --si es cuil validar contra el nro de documento
      if v_abreviatura = 'CUIL' then
         if fue_val_doc_cuil(:new.nro_documento, v_nro_documento) then
            null;
         end if;
      end if;
      --validar dígitos del cuil y cuit
      if v_abreviatura in ('CUIL','CUIT') then
         if fue_val_dig_cuil(:new.nro_documento) then
            null;
         end if;
      end if;
   end if;
END;
/

