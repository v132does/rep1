CREATE OR REPLACE PROCEDURE IT.PRL_INS_PERSONA
 (p_nro_documento  in  ba_personas.nro_documento%type,
 p_tip_documento in  ba_personas.cod_tip_documento%type,
 p_cod_pais in  ba_personas.cod_pais%type,
 p_nombre in  ba_personas.nom_completo%type, --nombre/s
 p_apellido in  ba_personas.nom_completo%type, --apellido/s
 p_tipo in  ba_personas.tipo%type,
 p_fec_nacimiento in  ba_per_fisicas.fec_nacimiento%type,
 p_cod_persona in out ba_personas.cod_persona%type)

IS

   r_bpers         ba_personas%rowtype;
   r_bperf         ba_per_fisicas%rowtype;
   r_bperj         ba_per_juridicas%rowtype;
   v_tip_persona   varchar2(3);
   v_posicion      number(05);
   v_posicion2      number(05);
   v_posicion3      number(05);
   v_coma          number(05);
   v_nombre        varchar2(200);
   v_apellido		 varchar2(200);

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

/*insertar la persona*/
PROCEDURE lp_ins_ba_personas
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
          cod_tip_documento, nro_documento, cod_pais)
      values
         (p_cod_persona, rp_bpers.nom_completo, rp_bpers.tipo,
          rp_bpers.cod_tip_documento, rp_bpers.nro_documento, rp_bpers.cod_pais);
   else
      --- Existe la persona actualizar datos
      raise_application_error(-20000,'Persona Existente con Documento '||rp_bpers.nro_documento);
   end if;
exception
  when others then
    If sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20000,'Ins.Persona '||sqlerrm);
    End if;
END;

/* Insertar persona fisica */
PROCEDURE lp_ins_ba_per_fisicas
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
      begin
         insert into ba_per_fisicas
            (cod_persona, pri_nombre, seg_nombre, pri_apellido,
            seg_apellido,  est_civil, cod_sexo, fec_nacimiento)
         values
            (p_cod_persona, rp_bperf.pri_nombre, rp_bperf.seg_nombre, rp_bperf.pri_apellido,
            rp_bperf.seg_apellido, rp_bperf.est_civil, rp_bperf.cod_sexo, r_bperf.fec_nacimiento);
      exception
         when others then
            raise_application_error(-20000,'Ins.ba_per_fisicas'||sqlerrm);
      end;
END;
/* Insertar persona Juridica */
PROCEDURE lp_ins_ba_per_juridicas
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
      begin
         insert into ba_per_juridicas
            (cod_persona, raz_social, nom_comercial)
         values
            (p_cod_persona, rp_bperj.raz_social, rp_bperj.nom_comercial);
      exception
         when others then
            raise_application_error(-20000,'Ins.ba_per_juridicas'||sqlerrm);
      end;
END;

/*procedimiento principal*/
begin
    v_nombre                    := upper(trim(p_nombre));
	 v_apellido                  := upper(trim(p_apellido));
    v_tip_persona               := p_tipo;
    r_bpers.nom_completo        := substr(v_nombre||' '||v_apellido,1,120);
    r_bpers.nro_documento       := p_nro_documento;
    r_bpers.cod_tip_documento   := p_tip_documento;
    if v_tip_persona ='F' then
       r_bpers.tipo           := 'F';
       r_bperf.fec_nacimiento := p_fec_nacimiento;
       --- Desmembrar nombre
       r_bperf.pri_nombre   := fug_obt_nombre(v_nombre,1);
       r_bperf.pri_apellido := fug_obt_nombre(v_apellido,1);
       r_bperf.seg_nombre   := fug_obt_nombre(v_nombre,2);
       r_bperf.seg_apellido := fug_obt_nombre(v_apellido,2);
       r_bperf.est_civil    := 'S';
       --determinar sexo
       if r_bperf.pri_nombre like '%A' or r_bperf.pri_nombre in ('CARMEN','GLADYS','MIRIAN','NANCY',
  	     'LOURDES','LILIAN','MERCEDES','IRENE','ISABEL','MARLENE','EDITH','BEATRIZ','NELLY','MYRIAN',
		  'RAQUEL','MIRIAM','LIZ','LUZ','ELIZABETH','GLADIS','CLOTILDE','CONCEPCION','MATILDE','RUTH',
		  'ESTHER','ESTER','MABEL','INGRID','DOLORES','INES') then
         r_bperf.cod_sexo     := 'F';
       else
         r_bperf.cod_sexo     := 'M';
       end if;
    else
       r_bpers.tipo          := 'J';
       r_bperj.raz_social    := trim(upper(substr(r_bpers.nom_completo,1,120)));
       r_bperj.nom_comercial := trim(upper(substr(r_bpers.nom_completo,1,65)));
    end if;
    r_bpers.cod_pais := p_cod_pais;
    if (r_bperf.pri_nombre is null) and r_bpers.tipo = 'F' then
          raise_application_error(-20001,'No se permite valores nulos para Primer Nombre');
		elsif (r_bperf.pri_apellido is null) and r_bpers.tipo = 'F'  then
          raise_application_error(-20002,'No se permite valores nulos para Primer Apellido');
		elsif r_bperj.raz_social is null and r_bpers.tipo = 'J'  then
          raise_application_error(-20003,'No se permite valores nulos para Razon Social');
		elsif r_bperj.nom_comercial is null and r_bpers.tipo = 'J'  then
          raise_application_error(-20004,'No se permite valores nulos para Nombre Comercial');
	else
      -- verifico antes si la persona con este nombre ya existe --
      if  lp_ver_dup_nombre(r_bpers.tipo, r_bperf, r_bperj, p_tip_documento) = 'N' then -- no hay duplicacion
         lp_ins_ba_personas(r_bpers, p_cod_persona);
         if r_bpers.tipo = 'F' then
            lp_ins_ba_per_fisicas(p_cod_persona, r_bperf);
         else
            lp_ins_ba_per_juridicas(p_cod_persona, r_bperj);
         end if;
      else
         raise_application_error(-20005,'Persona Existente con igual Nombre/s y Apellido/s');
      end if;
    end if;
exception
  when others then
    If sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20000,'Ins.Persona '||sqlerrm);
    End if;
end;
/

