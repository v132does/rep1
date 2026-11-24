CREATE OR REPLACE PROCEDURE IT.PRL_INS_PER_NO_CLIENTE
 (p_nro_documento  in  ba_personas.nro_documento%type,
 p_tip_documento in  ba_personas.cod_tip_documento%type,
 p_cod_pais in  ba_personas.cod_pais%type,
 p_nombre in  ba_personas.nom_completo%type,
 p_apellido in  ba_personas.nom_completo%type,
 p_tipo in  ba_personas.tipo%type,
 p_cod_persona in out ba_personas.cod_persona%type)

IS
--Procedimiento autonomo--
  PRAGMA AUTONOMOUS_TRANSACTION;
   r_bpers         ba_personas%rowtype;
   r_bperf         ba_per_fisicas%rowtype;
   r_bperj         ba_per_juridicas%rowtype;
   v_tip_persona   varchar2(3);
   v_posicion      number(05);
   v_posicion2      number(05);
   v_posicion3      number(05);
   v_coma          number(05);
   v_pri_nombre        varchar2(200);
   v_seg_nombre        varchar2(200);
   v_pri_apellido     varchar2(200);
   v_seg_apellido     varchar2(200);
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
       where cod_tip_documento = p_tip_documento
         and nro_documento     = p_nro_documento;
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
         (p_cod_persona, substr(p_nombre||' '||p_apellido,1,120), p_tipo,
          p_tip_documento, p_nro_documento, p_cod_pais);
          commit;
   else
      --- Existe la persona actualizar datos
      raise_application_error(-20000,'Persona Existente con Documento '||p_nro_documento);
   end if;
   
      begin
         insert into ba_per_fisicas
            (cod_persona, pri_nombre, seg_nombre, pri_apellido,
            seg_apellido,cod_pai_nacionalidad)
         values
            (p_cod_persona, v_pri_nombre, v_seg_nombre, v_pri_apellido,
            v_seg_apellido,p_cod_pais);
            commit;
      exception
         when others then
            raise_application_error(-20000,'Ins.ba_per_fisicas'||sqlerrm);
      end;
exception
  when others then
    If sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20000,'Ins.Persona '||sqlerrm);
    End if;
END;


begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
        --- Desmembrar nombre
   v_pri_nombre   := fug_obt_nombre(p_nombre,1);
   v_pri_apellido := fug_obt_nombre(p_apellido,1);
   v_seg_nombre   := fug_obt_nombre(p_nombre,2);
   v_seg_apellido := fug_obt_nombre(p_apellido,2);
   lp_ins_ba_personas(r_bpers, p_cod_persona);
exception
  when others then
    If sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20000,'Ins.Persona '||sqlerrm);
    End if;
end;
/

