CREATE OR REPLACE TRIGGER IT.TB_TM_PER_SIPRO
 BEFORE DELETE OR INSERT OR UPDATE
 ON TM_PER_SIPRO
 FOR EACH ROW

DECLARE

/* Obtener codigo del pais. */
FUNCTION LF_OBT_PAIS_SIPRO
 (P_PAIS IN VARCHAR2
 )
 RETURN NUMBER;
/* Insertar persona fisica SIPRO */
PROCEDURE LP_INS_BA_PEF_SIPRO
 (P_COD_PERSONA IN BA_PER_FISICAS.COD_PERSONA%TYPE
 ,RP_BPERF IN BA_PER_FISICAS%ROWTYPE
 );
/* Insertar persona Juridica SIPRO */
PROCEDURE LP_INS_BA_PEJ_SIPRO
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,RP_BPERJ IN BA_PER_JURIDICAS%ROWTYPE
 );
/* Insertar persona SIPRO */
PROCEDURE LP_INS_BA_PER_SIPRO
 (RP_BPERS IN BA_PERSONAS%ROWTYPE
 ,P_COD_PERSONA IN OUT BA_PERSONAS.COD_PERSONA%TYPE
 );
/* Inserta persona inhibida SIPRO */
PROCEDURE LP_INS_PER_INH_SIPRO
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
   
   v_pos_1         number(05);
   v_pos_2         number(05);
   v_pos_3         number(05);      
   v_pos_4         number(05);         
   
/* verifico si el nombre ya existe */
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
         and TRIM(b.pri_nombre) = TRIM(RP_BPERF.pri_nombre)
         and TRIM(b.seg_nombre) = TRIM(RP_BPERF.seg_nombre)
         and TRIM(b.pri_apellido) = TRIM(RP_BPERF.pri_apellido)
         and TRIM(b.seg_apellido) = TRIM(RP_BPERF.seg_apellido)
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
FUNCTION LF_OBT_PAIS_SIPRO
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
     return 1;
END;
/* Insertar persona fisica SIPRO */
PROCEDURE LP_INS_BA_PEF_SIPRO
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
      set pri_nombre   = TRIM(rp_bperf.pri_nombre),
          seg_nombre   = TRIM(rp_bperf.seg_nombre),
          pri_apellido = TRIM(rp_bperf.pri_apellido),
          seg_apellido = TRIM(rp_bperf.seg_apellido)
    where cod_persona  = p_cod_persona;
exception
   when no_data_found then
      insert into ba_per_fisicas
         (cod_persona, pri_nombre, seg_nombre,
          pri_apellido, seg_apellido,
          est_civil, cod_sexo)
      values
         (p_cod_persona, TRIM(rp_bperf.pri_nombre), TRIM(rp_bperf.seg_nombre),
          TRIM(rp_bperf.pri_apellido), TRIM(rp_bperf.seg_apellido),
          rp_bperf.est_civil, rp_bperf.cod_sexo);
END;
/* Insertar persona Juridica SIPRO */
PROCEDURE LP_INS_BA_PEJ_SIPRO
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
/* Insertar persona SIPRO */
PROCEDURE LP_INS_BA_PER_SIPRO
 (RP_BPERS IN BA_PERSONAS%ROWTYPE
 ,P_COD_PERSONA IN OUT BA_PERSONAS.COD_PERSONA%TYPE
 )
 IS
 v_nro_documento ba_personas.nro_documento%type;
 v_count number(5);
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
      
      --Verificar si no existe todavia una persona con la Secuencia Obtenida
      select count(1)
        into v_count
        from ba_personas x
       where x.cod_persona = p_cod_persona;
       
      if nvl(v_count,0) > 0 then
         --Obtener sgte. número de secuencia
         select s_cod_persona.nextval into p_cod_persona from dual;
      end if;  
      
      v_nro_documento := nvl(rp_bpers.nro_documento,'SI'||p_cod_persona);

      insert into ba_personas
         (cod_persona, nom_completo, tipo,
          cod_tip_documento, nro_documento, cod_pais, est_verificacion,
          obs_verificacion, fec_verificacion )
      values
         (p_cod_persona, rp_bpers.nom_completo, rp_bpers.tipo,
          rp_bpers.cod_tip_documento, v_nro_documento/*rp_bpers.nro_documento*/, rp_bpers.cod_pais,
          'V', 'DATOS DE SIPRO', sysdate);
   else
      --- Existe la persona actualizar datos
      update ba_personas
         set nom_completo = rp_bpers.nom_completo,
             cod_pais     = rp_bpers.cod_pais,
             tipo         = rp_bpers.tipo
       where cod_persona  = p_cod_persona;
   end if;
END;
/* Inserta persona inhibida SIPRO */
PROCEDURE LP_INS_PER_INH_SIPRO
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_OBSERVACION IN BA_PERSONAS.OBS_VERIFICACION%TYPE
 )
 IS
  v_nro_orden    ge_per_inhibidas.nro_orden%type;
  v_cod_causa ge_per_inhibidas.cod_causa%type;
BEGIN
   
   v_cod_causa := fug_obt_pardinamico('COD_CAU_SIPRO', null, null, null, null);
   
   begin
      select nro_orden
        into v_nro_orden
        from ge_per_inhibidas
       where cod_persona = p_cod_persona
         and cod_causa   = v_cod_causa;  ---Causa SIPRO
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
         (p_cod_persona, v_nro_orden, v_cod_causa,
          pag_cal.fu_obt_fec_actual(1), 'Personas inhibidas-SIPRO',
          substr(trim(p_observacion),1,500) ,'I');
   else
      --- Existe la persona actualizar datos
      update ge_per_inhibidas
         set detalle = substr(trim(p_observacion),1,500)
       where cod_persona  = p_cod_persona;
   end if;
END;
BEGIN
   v_cod_persona := null;
   if inserting then
      --v_tip_doc := fug_obt_pardinamico('TIP_DOC_SIPRO');
      --Tipo y Nro. de Documento
      if :new.nro_documento is not null and trim(:new.tip_documento) in ('CI','C.I.') then
         v_tip_doc                   := 1; --CI
         r_bpers.nro_documento       := REPLACE(:new.nro_documento, '.', '');
      elsif :new.nro_documento is not null and trim(:new.tip_documento) in ('RUC') then
         v_tip_doc                   := 6; --RUC
         r_bpers.nro_documento       := :new.nro_documento;         
      else  
         v_tip_doc                   := 10; --Sin Documento  
         r_bpers.nro_documento       := null;
      end if;
      r_bpers.cod_tip_documento   := v_tip_doc;     

      v_nombre                    := upper(trim(:new.nom_completo));
      r_bpers.nom_completo        := substr(v_nombre,1,120);
      v_tip_persona               := nvl(:new.tipo,'I'); --I=Individual, C=Company
      r_bpers.obs_verificacion    := ' Otros datos: '||nvl(trim(:new.dat_adicionales),'S/D');
      if trim(:new.fue_descripcion) is not null then
        r_bpers.obs_verificacion := r_bpers.obs_verificacion||' ; Fuente: '||trim(:new.fue_descripcion);
      end if;
      if trim(:new.Acu_Descripcion) is not null then
        r_bpers.obs_verificacion := r_bpers.obs_verificacion||' ; Acusación: '||trim(:new.Acu_Descripcion);
      end if;      
      if v_tip_persona = 'I' then
         r_bpers.tipo         := 'F';      
         
         v_pos_1              := instr(replace(v_nombre,',',' '),' ',1,1);           -- Posición del primer espacio
         v_pos_2              := instr(replace(v_nombre,',',' '),' ',v_pos_1 + 1,1); -- Posición del segundo espacio
         v_pos_3              := instr(replace(v_nombre,',',' '),' ',v_pos_2 + 1,1); -- Posición del tercer espacio
         
         if v_pos_1 > 0 and v_pos_2 > 0 and v_pos_3 > 0 then --3 Espacios, tomamos como 2 Nombres + 2 Apellidos
            r_bperf.pri_nombre      := trim(upper(substr(v_nombre,1, v_pos_1 - 1 )));
            r_bperf.seg_nombre      := trim(upper(substr(v_nombre,v_pos_1 + 1, v_pos_2 - v_pos_1 - 1)));            
            r_bperf.pri_apellido    := trim(upper(substr(v_nombre,v_pos_2 + 1, v_pos_3 - v_pos_2 - 1)));            
            r_bperf.seg_apellido    := trim(upper(substr(v_nombre,v_pos_3 + 1, length(v_nombre) - v_pos_3)));
         elsif v_pos_1 > 0 and v_pos_2 > 0 then --2 Espacios, tomamos como 1 Nombre + 2 Apellidos
            r_bperf.pri_nombre      := trim(upper(substr(v_nombre,1, v_pos_1 - 1 )));
            r_bperf.pri_apellido    := trim(upper(substr(v_nombre,v_pos_1 + 1, v_pos_2 - v_pos_1 - 1)));            
            r_bperf.seg_apellido    := trim(upper(substr(v_nombre,v_pos_2 + 1, length(v_nombre) - v_pos_2)));            
         elsif v_pos_1 > 0 then --1 Espacio, tomamos como 1 Nombre + 1 Apellido
            r_bperf.pri_nombre      := trim(upper(substr(v_nombre,1, v_pos_1 - 1 )));         
            r_bperf.pri_apellido    := trim(upper(substr(v_nombre,v_pos_1 + 1, length(v_nombre) - v_pos_1)));                     
         end if;
                  
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
      
      r_bpers.cod_pais := 1; --No viene en el archivo, Paraguay x Default
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
        -- Verifico antes si la persona con este nombre ya existe --
        if  lp_ver_dup_nombre(r_bpers.tipo, r_bperf, r_bperj, v_tip_doc) = 'N' then -- No hay duplicación

           lp_ins_ba_per_sipro(r_bpers, v_cod_persona); 
           if r_bpers.tipo = 'F' then
              lp_ins_ba_pef_sipro(v_cod_persona, r_bperf);
           else
              lp_ins_ba_pej_sipro(v_cod_persona, r_bperj);
           end if;
           --- Insertar persona inhibida SIPRO
           lp_ins_per_inh_sipro(v_cod_persona, r_bpers.obs_verificacion);
        end if;
      end if;   
      
   end if;   
EXCEPTION
  WHEN OTHERS THEN
    IF inserting then
     --Con cualquier error se graba el mensaje de error
     :new.msj_error := trim(substr(sqlerrm,1,3000));
    END IF;
END;
/

