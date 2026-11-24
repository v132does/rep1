create or replace procedure it.prt_val_datos_cliente is
  /*Este programa realiza las validaciones básicas para el alta masiva de tarjetas de crédito. */
  cursor c_datos is
  select *
    from ta_val_datos_cliente a;

  v_per_dupli                 varchar2(1) := 'N';
  v_cod_persona               ba_personas.cod_persona%type;
  v_cod_tip_documento         ba_personas.cod_tip_documento%type;
  v_fec_nacimiento            ba_per_fisicas.fec_nacimiento%type;
  v_edad                      number;
  v_cod_pai_nacionalidad      ba_per_fisicas.cod_pai_nacionalidad%type;
  v_pri_nombre                ba_per_fisicas.pri_nombre%type;
  v_pri_apellido              ba_per_fisicas.pri_apellido%type;
  v_seg_nombre                ba_per_fisicas.seg_nombre%type;
  v_seg_apellido              ba_per_fisicas.seg_apellido%type;
  v_tiene_ciu_dir             varchar2(1);
  v_dir_envio                 varchar2(1);
  v_tel_principal             varchar2(1);
  v_archivo                   varchar2(30);
  v_sql                       varchar2(4000);
begin
   for x in c_datos loop
      v_cod_tip_documento := fue_obt_tip_documento(x.tipo_doc);
      v_cod_persona := fue_obt_cod_persona_doc(v_cod_tip_documento, x.nro_documento);
      v_per_dupli := 'N';
      v_fec_nacimiento := null;
      v_edad := null;
      v_cod_pai_nacionalidad := null;
      v_pri_nombre := null;
      v_pri_apellido := null;
      v_seg_nombre := null;
      v_seg_apellido := null;
      v_tiene_ciu_dir := null;
      v_dir_envio := null;
      v_tel_principal := null;
      if v_cod_persona is not null then ---Si existe la persona en ITGF
        --Persona duplicada, con nro_documento duplicado (Sin tener en cuenta el tipo de documento)
        begin
          select 'N'
            into v_per_dupli
            from it.ba_personas p
           where p.nro_documento = replace(trim(x.nro_documento),'.','');
        exception
          when too_many_rows then
             v_per_dupli := 'S';
          when others then
             v_per_dupli := 'N';
        end;
        --Fecha Nacimiento, Edad
        begin
           select pf.fec_nacimiento, pf.cod_pai_nacionalidad, pf.pri_nombre, pf.pri_apellido, pf.seg_nombre, pf.seg_apellido
             into v_fec_nacimiento, v_cod_pai_nacionalidad, v_pri_nombre, v_pri_apellido, v_seg_nombre, v_seg_apellido
             from it.ba_per_fisicas pf
            where pf.cod_persona = v_cod_persona;
        exception
           when others then
              v_fec_nacimiento := null;
              v_cod_pai_nacionalidad := null;
              v_pri_nombre := null;
        end;
      end if;
      ---Tiene ciudad la dir_principal
      begin
        select 'S'
          into v_tiene_ciu_dir
          from it.ba_direcciones dir
         where dir.cod_persona = v_cod_persona
           and nvl(dir.principal,'N') = 'S'
           and nvl(dir.cod_ciudad,0) <> 0 ;
      exception
         when others then
           v_tiene_ciu_dir := 'N';
      end;
      ---Tiene dir_envio
      begin
         select 'S'
           into v_dir_envio
           from it.ge_dir_envios di
          where di.cod_persona = v_cod_persona
            and rownum = 1;
      exception
         when no_data_found then
            v_dir_envio := 'N';
         when others then
            v_dir_envio := 'N';
      end;
      ---tiene tel_principal  v_tel_principal
      begin
         select 'S'
           into v_tel_principal
           from it.ba_telefonos tel
          where tel.cod_persona = v_cod_persona
            and nvl(tel.principal,'N') = 'S';
      exception
         when no_data_found then
            v_tel_principal := 'N';
         when others then
            v_tel_principal := 'N';
      end;
      ---Actualizar todos los datos en tmp_tarj_mastercard
      begin
        update ta_val_datos_cliente t
           set t.per_dupli = nvl(v_per_dupli,'N'),
               t.tip_doc_it = v_cod_tip_documento,
               t.fec_nacimiento = v_fec_nacimiento,
               t.edad = to_number(to_char(sysdate,'yyyy')) - to_number(to_char(v_fec_nacimiento,'yyyy')),
               t.nacionalidad = v_cod_pai_nacionalidad,
               t.pri_nombre = v_pri_nombre,
               t.pri_apellido = v_pri_apellido,
               t.seg_nombre = v_seg_nombre,
               t.seg_apellido = v_seg_apellido,
               t.tiene_ciudad = v_tiene_ciu_dir,
               t.dir_envio = v_dir_envio,
               t.tel_principal = v_tel_principal,
               t.cod_persona_it = v_cod_persona
         where t.tipo_doc = x.tipo_doc
           and t.nro_documento = x.nro_documento;

         commit;
      exception
        when others then
          raise_application_error(-20001, 'Error al actualizar:'||sqlerrm);
      end;
   end loop;
   ---Generar un archivo TXT en el directorio UTL...
   v_archivo := 'DATOS_CLI_TARJ_'||TO_CHAR(trunc(sysdate),'yyyymmdd')||'.TXT';
   -- Cabecera
   V_SQL:='select ''TIP_DOCUMENTO''||CHR(9)||''NRO_DOCUMENTO''||CHR(9)||''PER_DUPLI''||CHR(9)||''TIP_DOC_IT''||CHR(9)||
                  ''FEC_NACIMIENTO''||CHR(9)||''EDAD''||CHR(9)||''NACIONALIDAD''||CHR(9)||''PRI_NOMBRE''||CHR(9)||
                  ''PRI_APELLIDO''||CHR(9)||''SEG_NOMBRE''||CHR(9)||''SEG_APELLIDO''||CHR(9)||''DIR_PRINCIPAL''||CHR(9)||
                  ''TIENE_CIUDAD''||CHR(9)||''DIR_ENVIO''||CHR(9)||''TEL_PRINCIPAL''||CHR(9)||''COD_PERSONA''
           from dual';

   prg_gen_archivo_txt(trim(v_archivo),V_SQL,'N');

    -- Detalle
   V_SQL:='select tipo_doc, nro_documento, per_dupli, tip_doc_it, fec_nacimiento, edad, nacionalidad, pri_nombre,
                  pri_apellido, seg_nombre, seg_apellido, dir_principal, tiene_ciudad, dir_envio, tel_principal, cod_persona_it
             from ta_val_datos_cliente';

   prg_gen_archivo_txt(trim(v_archivo),V_SQL,'N', chr(9), 'S');

exception
   when others then
     raise_application_error(-20000, 'Error al ejecutar:'||sqlerrm);
end;
/

