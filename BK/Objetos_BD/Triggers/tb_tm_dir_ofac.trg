CREATE OR REPLACE TRIGGER IT.TB_TM_DIR_OFAC
 BEFORE DELETE OR INSERT OR UPDATE
 ON TM_DIR_OFAC
 FOR EACH ROW

DECLARE

/* Recuperar ciudad */
FUNCTION LF_OBT_CIUD_OFAC
 (P_CIUDAD IN VARCHAR2
 ,P_COD_PAIS IN BA_CIUDADES.COD_PAIS%TYPE
 )
 RETURN NUMBER;
/* Insertar direccion */
PROCEDURE LP_INS_BA_DIR_OFAC
 (RP_BDIRE IN BA_DIRECCIONES%ROWTYPE
 ,P_NRO_DOCUMENTO IN BA_PERSONAS.NRO_DOCUMENTO%TYPE
 ,P_COD_TIP_DOCUMENTO IN BA_PERSONAS.COD_TIP_DOCUMENTO%TYPE
 );
/* Obtener codigo del pais. */
FUNCTION LF_OBT_PAIS_OFAC
 (P_PAIS IN VARCHAR2
 )
 RETURN NUMBER;
   v_nro_documento varchar2(10);
   v_tip_doc       ba_personas.cod_tip_documento%type;
   r_bdire         ba_direcciones%rowtype;

/* Recuperar ciudad */
FUNCTION LF_OBT_CIUD_OFAC
 (P_CIUDAD IN VARCHAR2
 ,P_COD_PAIS IN BA_CIUDADES.COD_PAIS%TYPE
 )
 RETURN NUMBER
 IS
v_cod_ciudad ba_ciudades.cod_ciudad%type;
BEGIN
   select cod_ciudad
     into v_cod_ciudad
     from ba_ciudades
    where upper(descripcion) like upper(p_ciudad)
      and cod_pais = p_cod_pais;
    return v_cod_ciudad;
exception
   when no_data_found then
     return null; --- WASHINGTON
END;
/* Insertar direccion */
PROCEDURE LP_INS_BA_DIR_OFAC
 (RP_BDIRE IN BA_DIRECCIONES%ROWTYPE
 ,P_NRO_DOCUMENTO IN BA_PERSONAS.NRO_DOCUMENTO%TYPE
 ,P_COD_TIP_DOCUMENTO IN BA_PERSONAS.COD_TIP_DOCUMENTO%TYPE
 )
 IS
v_cod_persona     ba_personas.cod_persona%type;
v_cod_direccion   ba_direcciones.cod_direccion%type;
v_cantidad        number;
v_principal       varchar2(1);
BEGIN
   BEGIN
      select cod_persona into v_cod_persona
        from ba_personas
       where cod_tip_documento = p_cod_tip_documento
         and nro_documento = p_nro_documento;
   exception
      when no_data_found then
         v_cod_persona  := null;
         --raise_application_error(-20000,'Persona no registrada '||p_nro_documento);
   END;
   if v_cod_persona is not null then
       --- Recuperar codigo de direccion
       BEGIN
          select cod_direccion
            into v_cod_direccion
            from ba_direcciones
           where cod_persona = v_cod_persona
             and upper(trim(direccion)) like upper(trim(rp_bdire.direccion));
       exception
          when no_data_found then
             v_cod_direccion := null;
       END;
       BEGIN
          select count(*)
            into v_cantidad
            from ba_direcciones
           where cod_persona = v_cod_persona
             and principal = 'S';
          if v_cantidad > 0 then
             v_principal := 'N';
          else
             v_principal := 'S';
          end if;
       exception
          when others then
             v_principal := 'N';
       end;

       If v_cod_direccion is null then
         select nvl(max(cod_direccion),0) + 1
         into v_cod_direccion
         from ba_direcciones
         where cod_persona = v_cod_persona;
         -- insertar direccion
          insert into ba_direcciones
             (cod_persona, cod_direccion,tipo, principal, direccion, cod_pais, cod_ciudad)
          values
             (v_cod_persona,v_cod_direccion, 'P', v_principal, rp_bdire.direccion, rp_bdire.cod_pais, rp_bdire.cod_ciudad);
       else
          -- actualizar direccion
          update ba_direcciones
             set direccion     = rp_bdire.direccion,
                 cod_pais      = rp_bdire.cod_pais,
                 cod_ciudad    = rp_bdire.cod_ciudad
           where cod_persona   = v_cod_persona
             and cod_direccion = v_cod_direccion;
       end if;
   end if;
END;
/* Obtener codigo del pais. */
FUNCTION LF_OBT_PAIS_OFAC
 (P_PAIS IN VARCHAR2
 )
 RETURN NUMBER
 IS
v_cod_pais ba_paises.cod_pais%type;
BEGIN
   select cod_pais
     into v_cod_pais
     from ba_paises
    where upper(descripcion) like upper(p_pais)
      and rownum=1;
    return v_cod_pais;
exception
   when no_data_found then
     return fug_obt_pardinamico('COD_PAI_EEUU', null, null, null, null); --- ESTADOS UNIDOS
END;
BEGIN
   if inserting then
      v_tip_doc           := fug_obt_pardinamico('TIP_DOC_OFAC');
      v_nro_documento     := 'OFAC-'||trim(:new.nro_documento);
      r_bdire.direccion   := substr(trim(:new.direccion),1,80);
      r_bdire.cod_pais    := lf_obt_pais_ofac(trim(:new.pais));
      r_bdire.cod_ciudad  := lf_obt_ciud_ofac(trim(:new.ciudad), r_bdire.cod_pais);
      r_bdire.observacion := trim(:new.observacion);
      -------------------------------
      lp_ins_ba_dir_ofac(r_bdire, v_nro_documento, v_tip_doc);
   end if;
EXCEPTION
  WHEN OTHERS THEN
    IF inserting then
     -- con cualquier error se graba el mensaje de error
     :new.msj_error := substr(sqlerrm,1,3000);
    END IF;
END;
/

