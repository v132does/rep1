CREATE OR REPLACE FUNCTION IT.FUE_VAL_TIP_DOC
 (P_TIP_DOC IN NUMBER
 ,P_DOCUMENTO IN VARCHAR2
 ,P_MEN_ERROR OUT VARCHAR2
 ,P_TIPO IN VARCHAR2 default null
 ,P_SEXO IN VARCHAR2 default null)
 RETURN BOOLEAN
 IS

V_FORMATO VARCHAR2(20);
V_CONTADOR NUMBER(2) := 0;
V_DOCUMENTO VARCHAR2(20);
V_VERIF VARCHAR2(20);
V_MAXIMA NUMBER(2);
V_MINIMA NUMBER(2);
v_estado ba_tip_documentos.estado%type;
v_abreviatura ba_tip_documentos.abreviatura%type;
v_tipo ba_tip_documentos.tip_persona%type;
cursor formato is
  select formato,lon_maxima,lon_minima,estado, abreviatura, tip_persona
    from ba_tip_documentos
   where cod_tip_documento = p_tip_doc;
begin
  open formato;
  fetch formato into v_formato,v_maxima,v_minima, v_estado, v_abreviatura, v_tipo;
  close formato;
  If nvl(v_estado, 'I') != 'A' then
     raise_application_error(-20001,'Tipo de Documento Inactivo');
  End If;
  --validar por tipo de persona
  if p_tipo is not null then
    if p_tipo = 'F' and v_tipo not in ('F','A') then
       raise_application_error(-20002,'Tipo de Documento no permitido para Persona Física');
    elsif p_tipo = 'J' and v_tipo not in ('J','A') then
       raise_application_error(-20003,'Tipo de Documento no permitido para Persona Jurídica');
    End If;
  end if;
  --validar por sexo
  if p_sexo is not null then
    if v_abreviatura = 'LEN' and p_sexo <> 'M' then
       raise_application_error(-20004,'Tipo de Documento sólo permitido para sexo Masculino');
    elsif v_abreviatura = 'LCV' and p_sexo <> 'F' then
       raise_application_error(-20005,'Tipo de Documento sólo permitido para sexo Femenino');
    End If;
  end if;
  --validar tamaño
  If v_maxima = v_minima then
    If length(p_documento) < v_maxima or length(p_documento) > v_maxima then
      raise_application_error(-20006,'Debe tener una longitud de '||to_char(v_maxima)||' caracteres');
    End if;
  elsif length(p_documento) < v_minima then
    raise_application_error(-20007,'Debe tener una longitud mínima de '||to_char(v_minima)||' caracteres');
  elsif length(p_documento) > v_maxima then
    raise_application_error(-20008,'Debe tener una longitud máxima de '||to_char(v_maxima)||' caracteres');
  End if;
  --validar formato
  For c in 1..length(p_documento) loop
    v_contador  := v_contador + 1;
    v_documento := substr(p_documento,v_contador,1);
    v_verif     := substr(v_formato,v_contador,1);
    If v_verif = 'A' then
      If upper(v_documento) not in ('A','B','C','D','E','F','G','H','I','J','K',
                               'L','Ñ','O','P','Q','R','S','T','U','V','W','X','Y','Z') then
        raise_application_error(-20009,'Formato Incorrecto para el tipo de Documento.Debe ser un valor alfabético,en la posición '||to_char(v_contador));
      End if;
    elsif v_verif = '9' then
      If v_documento not in ('0','1','2','3','4','5','6','7','8','9') then
        --Si es cedula y es la ultima posicion puede tener una LETRA
        IF v_contador = length(p_documento) AND v_abreviatura = 'CI' THEN
          NULL;
        ELSE
          raise_application_error(-20010,'Formato Incorrecto para el tipo de Documento.Debe ser un valor numérico en la posición '||to_char(v_contador));
        END IF;
      else
        --controlar que no tenga cero en la primer posición, si es cédula
        if v_documento = '0' and v_contador = 1 and v_abreviatura = 'CI' then
          raise_application_error(-20011,'Formato Incorrecto para el tipo de Documento.Nro. de Documento no puede ser 0 en la posición inicial');
        end if;
      End if;
    elsif v_verif = 'X' then
      null;
    else
       -- cualquier otro caracte
       if v_documento <> v_verif then
          raise_application_error(-20012,'Formato incorrecto. Debe ingresar '||v_verif||' en la Posicion '||c);
       end if;
    --elsif v_verif = '=' then
    --  If v_documento <> v_
    --  End if;
    End if;
  End loop;
  if fue_val_es_numerico(p_documento) = 'S' then
     --validar números
     if v_abreviatura = 'DNI' and to_number(p_documento) < 10000000 then
       raise_application_error(-20013,'Nro. de DNI debe ser Mayor a 10.000.000');
     elsif v_abreviatura in ('LEN','LCV') and to_number(p_documento) >= 10000000 then
       raise_application_error(-20014,'Nro. de LEN/LCV debe ser Menor a 10.000.000');
     elsif v_abreviatura = 'CUIT' and substr(p_documento,1,1) <> 3 then
       raise_application_error(-20015,'Nro. de CUIT debe comenzar con el número 3');
     end if;
   end if;
  return TRUE;
End;

 
/
