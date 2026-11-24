CREATE OR REPLACE TRIGGER IT.TB_TM_PER_OFAC
 BEFORE DELETE OR INSERT OR UPDATE
 ON TM_PER_OFAC
 FOR EACH ROW

DECLARE

/* Obtener codigo del pais. */
FUNCTION LF_OBT_PAIS_OFAC
 (P_PAIS IN VARCHAR2
 )
 RETURN NUMBER;
/* Insertar persona fisica OFAC */
PROCEDURE LP_INS_BA_PEF_OFAC
 (P_COD_PERSONA IN BA_PER_FISICAS.COD_PERSONA%TYPE
 ,RP_BPERF IN BA_PER_FISICAS%ROWTYPE
 );
/* Insertar persona Juridica OFAC */
PROCEDURE LP_INS_BA_PEJ_OFAC
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,RP_BPERJ IN BA_PER_JURIDICAS%ROWTYPE
 );
/* Insertar persona OFAC */
PROCEDURE LP_INS_BA_PER_OFAC
 (RP_BPERS IN BA_PERSONAS%ROWTYPE
 ,P_COD_PERSONA IN OUT BA_PERSONAS.COD_PERSONA%TYPE
 );
/* Inserta persona inhibida OFAC */
PROCEDURE LP_INS_PER_INH_OFAC
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_OBSERVACION IN BA_PERSONAS.OBS_VERIFICACION%TYPE
 );
   r_bpers         ba_personas%rowtype;
   r_bperf         ba_per_fisicas%rowtype;
   r_bperj         ba_per_juridicas%rowtype;
   v_tip_doc       ba_personas.cod_tip_documento%type;
   v_cod_persona   ba_personas.cod_persona%type;
   v_tip_persona   varchar2(12);
   v_posicion      number(05);
   v_coma          number(05);
   v_nombre        varchar2(200);
/* verifico si el nombre ya exists */
FUNCTION lp_ver_dup_nombre
    (p_tipo IN varchar2,
     RP_BPERF IN BA_PER_FISICAS%ROWTYPE,
     RP_BPERJ IN BA_PER_JURIDICAS%ROWTYPE,
     P_TIP_DOC NUMBER
     )
  RETURN VARCHAR2 IS
v_cantidad number := 0;
BEGIN
   if p_tipo = 'F' then --fisico
      select count(*)
        into v_cantidad
        from ba_per_fisicas b, ba_personas a
       where a.cod_persona = b.cod_persona
         and b.pri_nombre = RP_BPERF.pri_nombre
         and b.seg_nombre = RP_BPERF.seg_nombre
         and b.pri_apellido = RP_BPERF.pri_apellido
         and b.seg_apellido = RP_BPERF.seg_apellido
         and a.cod_tip_documento = p_tip_doc
         and rownum = 1;
   else
      select count(*)
        into v_cantidad
        from ba_per_juridicas b, ba_personas a
       where a.cod_persona = b.cod_persona
         and b.raz_social = RP_BPERJ.raz_social
         and a.cod_tip_documento = p_tip_doc
         and rownum = 1;
   end if;
   if nvl(v_cantidad,0) > 0 then
      return 'S'; -- ya existe un nombre parecido
   else
      return 'N'; -- no existe nombre
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
     return FUG_OBT_PARDINAMICO('COD_PAI_EEUU', NULL, NULL, NULL, NULL); --- Obs: Actualizar segun usuario
END;
/* Insertar persona fisica OFAC */
PROCEDURE LP_INS_BA_PEF_OFAC
 (P_COD_PERSONA IN BA_PER_FISICAS.COD_PERSONA%TYPE
 ,RP_BPERF IN BA_PER_FISICAS%ROWTYPE
 )
 IS
v_cod_persona ba_personas.cod_persona%type;
BEGIN
   select cod_persona
     into v_cod_persona
     from ba_per_fisicas
    where cod_persona = p_cod_persona;
   --- Actualizar
   update ba_per_fisicas
      set pri_nombre   = rp_bperf.pri_nombre,
          seg_nombre   = rp_bperf.seg_nombre,
          pri_apellido = rp_bperf.pri_apellido,
          seg_apellido = rp_bperf.seg_apellido
    where cod_persona  = p_cod_persona;
exception
   when no_data_found then
      insert into ba_per_fisicas
         (cod_persona, pri_nombre, seg_nombre,
          pri_apellido, seg_apellido,
          est_civil, cod_sexo)
      values
         (p_cod_persona, rp_bperf.pri_nombre, rp_bperf.seg_nombre,
          rp_bperf.pri_apellido, rp_bperf.seg_apellido,
          rp_bperf.est_civil, rp_bperf.cod_sexo);
END;
/* Insertar persona Juridica OFAC */
PROCEDURE LP_INS_BA_PEJ_OFAC
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,RP_BPERJ IN BA_PER_JURIDICAS%ROWTYPE
 )
 IS
v_cod_persona ba_personas.cod_persona%type;
BEGIN
   select cod_persona
     into v_cod_persona
     from ba_per_juridicas
    where cod_persona = p_cod_persona;
   --- Actualizar
   update ba_per_juridicas
      set raz_social    = rp_bperj.raz_social,
          nom_comercial = rp_bperj.nom_comercial
    where cod_persona  = p_cod_persona;
exception
   when no_data_found then
      insert into ba_per_juridicas
         (cod_persona, raz_social, nom_comercial)
      values
         (p_cod_persona, rp_bperj.raz_social, rp_bperj.nom_comercial);
END;
/* Insertar persona OFAC */
PROCEDURE LP_INS_BA_PER_OFAC
 (RP_BPERS IN BA_PERSONAS%ROWTYPE
 ,P_COD_PERSONA IN OUT BA_PERSONAS.COD_PERSONA%TYPE
 )
 IS
BEGIN
   begin
      select cod_persona
        into p_cod_persona
        from ba_personas
       where cod_tip_documento = rp_bpers.cod_tip_documento
         and nro_documento     = rp_bpers.nro_documento;
   exception
      when no_data_found then
         p_cod_persona := null;
   end;
   if p_cod_persona is null then
      --- No existe la persona
      select s_cod_persona.nextval into p_cod_persona from dual;

      insert into ba_personas
         (cod_persona, nom_completo, tipo,
          cod_tip_documento, nro_documento, cod_pais, est_verificacion,
          obs_verificacion, fec_verificacion )
      values
         (p_cod_persona, rp_bpers.nom_completo, rp_bpers.tipo,
          rp_bpers.cod_tip_documento, rp_bpers.nro_documento, rp_bpers.cod_pais,
          'V', 'DATOS DE OFAC', sysdate);
   else
      --- Existe la persona actualizar datos
      update ba_personas
         set nom_completo = rp_bpers.nom_completo,
             cod_pais     = rp_bpers.cod_pais,
             tipo         = rp_bpers.tipo
       where cod_persona  = p_cod_persona;
   end if;
END;
/* Inserta persona inhibida OFAC */
PROCEDURE LP_INS_PER_INH_OFAC
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_OBSERVACION IN BA_PERSONAS.OBS_VERIFICACION%TYPE
 )
 IS
  v_nro_orden    ge_per_inhibidas.nro_orden%type;
  v_cod_cau_ofac ge_per_inhibidas.cod_causa%type;
BEGIN
   v_cod_cau_ofac := fug_obt_pardinamico('COD_CAU_OFAC', null, null, null, null);
   begin
      select nro_orden
        into v_nro_orden
        from ge_per_inhibidas
       where cod_persona = p_cod_persona
         and cod_causa   = v_cod_cau_ofac;  --- Causa OFAC
   exception
      when no_data_found then
         v_nro_orden := null;
   end;
   if v_nro_orden is null then
      --- No existe la persona
      select nvl(max(nvl(nro_orden,0)),0) + 1 into v_nro_orden
        from ge_per_inhibidas
       where cod_persona = p_cod_persona;
      insert into ge_per_inhibidas
         (cod_persona, nro_orden, cod_causa,
          fec_inicio, origen, detalle, estado)
      values
         (p_cod_persona, v_nro_orden, v_cod_cau_ofac,
          pag_cal.fu_obt_fec_actual(1), 'Personas inhibidas internacionalmente',
          substr(trim(p_observacion),1,500),'I');
   else
      --- Existe la persona actualizar datos
      update ge_per_inhibidas
         set detalle = substr(trim(p_observacion),1,500)
       where cod_persona  = p_cod_persona;
   end if;
END;
BEGIN
   if inserting then
      v_tip_doc := fug_obt_pardinamico('TIP_DOC_OFAC');
      r_bpers.cod_tip_documento   := v_tip_doc;
      r_bpers.nro_documento       := 'OFAC-'||trim(:new.nro_documento);
      v_nombre                    := upper(trim(:new.nom_completo));
      r_bpers.nom_completo        := substr(v_nombre,1,120);
      v_tip_persona               := trim(:new.tip_persona);
      r_bpers.obs_verificacion    := 'Cargo: '||trim(:new.cargo)||
                                     ' Otros datos: '||trim(:new.dat_adicionales);
      if trim(lower(v_tip_persona)) = 'individual' then
         r_bpers.tipo         := 'F';
         --- Desmembrar nombre
         v_posicion           := instr(v_nombre,' ',1,1); -- posicion del primer espacio
         v_coma               := instr(v_nombre,',',1,1); -- posicion de la coma
         r_bperf.pri_apellido := NVL(trim(replace(upper(substr(v_nombre,1,v_posicion-1)),',',' ')), '.');
         r_bperf.seg_apellido := trim(replace(upper(substr(v_nombre,v_posicion+1,(v_coma-v_posicion)-1)),',',' '));
         v_posicion           := instr(v_nombre,' ',v_coma,2); -- posicion del segundo espacio
         if v_posicion = 0 then
            v_posicion := length(v_nombre)+1;
         end if;
         r_bperf.pri_nombre   := trim(replace(upper(substr(v_nombre,v_coma+1,(v_posicion-v_coma)-1)),',',' '));
         r_bperf.seg_nombre   := trim(replace(upper(substr(v_nombre,v_posicion+1,30)),',',' '));
         ---
         r_bperf.est_civil    := 'S';
         r_bperf.cod_sexo     := 'M';	
				 r_bpers.nom_completo := r_bperf.pri_nombre||' '||r_bperf.seg_nombre||' '||r_bperf.pri_apellido||' '||r_bperf.seg_apellido;
				 r_bpers.nom_completo := replace(trim(r_bpers.nom_completo),'  ',' ');
      else
         r_bpers.tipo          := 'J';
         r_bperj.raz_social    := trim(upper(substr(v_nombre,1,120)));
         r_bperj.nom_comercial := trim(upper(substr(v_nombre,1,65)));
      end if;
      r_bpers.cod_pais := lf_obt_pais_ofac(:new.pais);
      if (r_bperf.pri_nombre is null) and r_bpers.tipo = 'F' then
            :new.msj_error := 'No se permite valores nulos para Primer Nombre';
  		elsif (r_bperf.pri_apellido is null) and r_bpers.tipo = 'F'  then
            :new.msj_error := 'No se permite valores nulos para Primer Apellido';
  		elsif r_bperj.raz_social is null and r_bpers.tipo = 'J'  then
            :new.msj_error := 'No se permite valores nulos para Razon Social';
  		elsif r_bperj.nom_comercial is null and r_bpers.tipo = 'J'  then
            :new.msj_error := 'No se permite valores nulos para Nombre Comercial';
			else
        -------------------------------
        -- verifico antes si la persona con este nombre ya existe --
        if  lp_ver_dup_nombre(r_bpers.tipo, r_bperf, r_bperj, v_tip_doc) = 'N' then -- no hay duplicacion
           lp_ins_ba_per_ofac(r_bpers, v_cod_persona);
           if r_bpers.tipo = 'F' then
              lp_ins_ba_pef_ofac(v_cod_persona, r_bperf);
           else
              lp_ins_ba_pej_ofac(v_cod_persona, r_bperj);
           end if;
           --- Insertar persona inhibida OFAC
           lp_ins_per_inh_ofac(v_cod_persona, r_bpers.obs_verificacion);
        end if;
      end if;
   end if;
EXCEPTION
  WHEN OTHERS THEN
    IF inserting then
     -- con cualquier error se graba el mensaje de error
     :new.msj_error := substr(sqlerrm,1,3000);
    END IF;
END;
/

