create or replace procedure it.pre_val_dat_personas is

  v_existe      varchar2(1) := 'S';
  v_cod_persona BA_DAT_PERSONAS_TMP.cod_persona%type;
  v_dir_correo  BA_DAT_PERSONAS_TMP.dir_correo%type;
  v_telefono    BA_DAT_PERSONAS_TMP.telefono%type;
  v_direccion   BA_DAT_PERSONAS_TMP.direccion%type;
  
  v_error varchar2(1) := 'N';
  v_pre_fijo     varchar2(3);
  --
  v_nom_usuario  BA_DAT_PERSONAS_TMP.dir_correo%type; 
  v_nom_dominio  BA_DAT_PERSONAS_TMP.dir_correo%type; 
  v_caracter     varchar2(1);
  v_posicion     number(3);
  v_car_invalido number(3);
  v_con_caracter number(3) := 0;
  
begin
  -- Author  : Gabriel Capo
  -- Created : 19/12/2013
  -- Purpose : Valida los datos insertados en BA_DAT_PERSONAS_TMP, a través del proc. importacion de datos ACT_DATOS_TMP

  begin
    select 'S'
      into v_existe
      from BA_DAT_PERSONAS_TMP b;
  exception
       when no_data_found then
           v_error := 'S';
           RAISE_APPLICATION_ERROR(-20000,'No hay datos que procesar, favor verifique');
       when too_many_rows then
            v_existe := 'S';
  end;
        
  for xx in (select a.cod_persona,
                   a.dir_correo,
                   a.telefono,
                   a.direccion
              from BA_DAT_PERSONAS_TMP a) loop
     
    -------------- validacion --------------
    --COD_PERSONA
        v_cod_persona   := xx.cod_persona;
        
        begin
          select 'S'
            into v_existe
            from ba_personas b
           where b.cod_persona = v_cod_persona;
        exception
             when no_data_found then
                 v_error := 'S';
                 RAISE_APPLICATION_ERROR(-20000,'No existe el nro cliente : ' || v_cod_persona || ', favor verifique');
        end;
      
     -------------- validacion --------------
     --DIR_CORREO
        v_dir_correo  := xx.dir_correo;
        
        if v_dir_correo is null then
           v_error := 'S';
          RAISE_APPLICATION_ERROR(-20000,'Direccion de Correo invalida, debe tener por lo menos un correo que actualizar, cliente: '||v_cod_persona);
        end if;
        
        v_posicion := instr(v_dir_correo,'@');
        v_nom_usuario := substr(v_dir_correo,1,instr(v_dir_correo,'@')-1);
        v_nom_dominio := substr(v_dir_correo,instr(v_dir_correo,'@')+1);
        v_con_caracter := 0;
        v_car_invalido := instr(translate(v_dir_correo,' áéíóúàèìòùÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙ,+´~|°ºª¬!"#$%&/()=?¡¿*¨{}^`·[]:;><ÇÃ%''',
                                                 '******************************************************************'),'*');
                                                 
        for i in 1..length(v_dir_correo) loop
          v_caracter := substr(v_dir_correo,i,1);
          if v_caracter = '@' then
            v_con_caracter := v_con_caracter + 1;
          end if;
        end loop;
        
        if v_posicion <= 1 or v_posicion = length(v_dir_correo) or v_con_caracter > 1 then
          v_error := 'S';
          RAISE_APPLICATION_ERROR(-20000,'Direccion de Correo debe tener un único @ que no este al principio ni al final, cliente: '||v_cod_persona);
        elsif substr(v_nom_usuario,1,1) = '.' or substr(v_nom_usuario,length(v_nom_usuario),1) = '.' then
          v_error := 'S';
          RAISE_APPLICATION_ERROR(-20000,'Usuario No puede empezar ni terminar con un punto, cliente: '||v_cod_persona);
        elsif substr(v_nom_dominio,1,1) = '.' or substr(v_nom_dominio,length(v_nom_dominio),1) = '.' or instr(v_nom_dominio,'.') = 0 then
          v_error := 'S';
          RAISE_APPLICATION_ERROR(-20000,'Domimio debe terner al menos un punto que No este al principio ni al final, cliente: '||v_cod_persona);
        elsif v_car_invalido > 0 then
          v_error := 'S';
          RAISE_APPLICATION_ERROR(-20000,'Carater inválido: '|| substr(v_dir_correo,v_car_invalido,1));
        elsif instr(v_dir_correo,'..') > 0 then
          v_error := 'S';
          RAISE_APPLICATION_ERROR(-20000,'No puede ingresar punto consecutivamente, cliente: '||v_cod_persona);
        elsif length(v_nom_usuario) > 64 then
          v_error := 'S';
          RAISE_APPLICATION_ERROR(-20000,'El nombre de usuario no puede ser mayor a 64 caracteres, cliente: '||v_cod_persona);
        elsif length(v_nom_dominio) > 250 then
          v_error := 'S';
          RAISE_APPLICATION_ERROR(-20000,'El dominio no puede ser mayor a 250 caracteres, cliente: '||v_cod_persona);
        end if;
       
      -------------- validacion -------------- 
      --TELEFONO
        
        begin
          select to_number(b.telefono)
            into v_telefono
            from BA_DAT_PERSONAS_TMP b
           where b.cod_persona = v_cod_persona;
        exception
             when too_many_rows then
                 RAISE_APPLICATION_ERROR(-20000,'Cliente cargado mas de una vez, cliente : '||v_cod_persona||', favor verifique');
             when others then
                 v_error := 'S';
                 RAISE_APPLICATION_ERROR(-20000,'Caracter no valido, para nro de telefono, cliente : '||v_cod_persona||', favor verifique');
        end;
        
        v_telefono := xx.telefono;
        if length(v_telefono) <> 10 then
           v_error := 'S';
           RAISE_APPLICATION_ERROR(-20000,'Telefono no valido, longitud incorrecta, cliente : '||v_cod_persona||', favor verifique');
        end if;
        
        v_pre_fijo := substr(v_telefono,0,3);
        if v_pre_fijo not in ('098','099','097','096') then
           v_error := 'S';
           RAISE_APPLICATION_ERROR(-20000,'Prefijo de telefono no valido, cliente : '||v_cod_persona||', favor verifique');
        end if;
        
       -------------- validacion ----------------
       --DIRECCION
        v_direccion     := xx.direccion;
        
        if length(v_direccion)>80 then
           v_error := 'S';
           RAISE_APPLICATION_ERROR(-20000,'Dato de direccion, supera limite establecido (80 caracteres), cliente : '||v_cod_persona||', favor verifique');
        end if;


  end loop;
  
  
 if v_error <> 'S' then
    pre_ins_dat_personas();
 end if;
  
  
  
end pre_val_dat_personas;
/

