create or replace function it.FUL_INS_TRA_RECIBIDAS(p_mensaje IN varchar2,p_archivo in varchar2)
return varchar2 is

/*03/2017 Función para levantar la mensajeria del Swift en forma automática,
se depositará en una carpeta y através de un socket se llamará a esta función
DEVUELVE: ok sino hubo error, si hubo devuelve texto de error
*/

FUNCTION FU_OBT_OCURRENCIAS (p_mensaje in varchar2, p_valor in varchar2)
 return number;

  v_longitud number(6);
  v_ocurrencias number(20);
  v_texto varchar2(1000) := null;
  v_cuerpo varchar2(2999) := null;
  v_campo varchar2(2999) := null;
  v_valor varchar2(1000) := null;
  v_cabecera varchar2(1000) := null;
  v_pie  varchar2(1000);
  v_salto varchar2(2) := CHR(10);
  v_salto1 varchar2(2):= CHR(13);
  v_salto2 varchar2(6):= CHR(10)||CHR(13);
  v_id_fin_cabecera varchar2(20):='}{4:';
  v_id_ini_pie varchar2(20):='}{5:';
  v_n_fin_cabecera number(4);
  v_n_ini_pie number(4);
  v_pos_inicial number(4) := 1;
  v_pos_final number(4) := 1;
  v_diferencia number(4) := 1;
  v_contador number(10):=0;
  v_resultado varchar2(100):=null;
  v_max_hora varchar2(20);
  v_hora varchar2(20);
  v_nro_sec_lote  number (6);
  v_can_reg_procesados varchar2(3000);
  v_id_gpi number(10);
  v_es_gpi varchar2(100):='N';
  v_codigo varchar2(300);
  v_lugar varchar2(2000);
  v_espacio number(10);
  v_long_cad number(10);
  v_aux_dif number(10):=0;

FUNCTION FU_OBT_OCURRENCIAS(p_mensaje in varchar2,p_valor in varchar2)
RETURN NUMBER
IS
 /*Obtener la cantidad de Ocurrencias de un valor en una cadena*/
 v_respuesta NUMBER;
Begin
 Select (length(p_mensaje)-length(replace(p_mensaje,p_valor,'')))/length(p_valor)
  into v_respuesta
    from DUAL;

 return v_respuesta;
exception
    when others then
       return 0;
end FU_OBT_OCURRENCIAS;

PROCEDURE lp_ins_tmp(p_texto in varchar2) is
 /*Inserción en tabla temporal*/
Begin
     --Obtenemos la Máxima hora
     begin
       select max(a.nro_orden)
         into v_max_hora
         from lc_swift_tmp a;
     exception
       when no_data_found then
          v_max_hora:= null;
       when others then
          v_max_hora:= null;
     end;
     if v_max_hora is null then
        v_max_hora:= to_char(sysdate,'hh24:mi:ss');
     end if;
     v_hora:= pag_gen.FU_OBT_SIG_SEGUNDO(v_max_hora);
     insert into lc_swift_tmp(nro_orden,texto)
     values (v_hora,trim(p_texto));
     commit;
exception
   when DUP_VAL_ON_INDEX then
     null;
   when others then
     v_resultado:='Error al grabar'||sqlerrm;
END;

PROCEDURE lp_act_log(p_codigo in varchar2,p_respuesta in varchar2) is
Begin
   update ba_log_swift a
     set a.respuesta = trim(p_respuesta)
      where a.codigo = p_codigo
           and trunc(a.fec_insercion)=trunc(sysdate);
           commit;
exception
   when DUP_VAL_ON_INDEX then
     null;
   when others then
     v_resultado:='Error al act.Log'||sqlerrm;
END;

begin
     /*** Inicio de Proceso Principal ***/
    v_lugar:= null;
     --Identificamos si es Swift, Insertamos en la tabla de Log
    v_lugar:= 'Inicio de Proceso';
    v_id_gpi:= 0;
    v_es_gpi:= null;
    v_id_gpi:= instr(p_mensaje,'{111:001}');
    if nvl(v_id_gpi,0) > 0 then
      v_es_gpi:='S';
    else
      v_es_gpi:='N';
    end if;
    v_lugar:= 'Obtener Codigo de Swift';
    --Obtenermos el codigo de mensajeria Swift-> Campo :20:
     v_codigo:=null;
     v_pos_inicial:= instr(p_mensaje,':20:'/*v_salto*/)+4 ;
     v_pos_final:=instr(p_mensaje,':23B:'/*v_salto*/) ;
     v_diferencia:= v_pos_final -v_pos_inicial;
     v_codigo:= substr(p_mensaje, v_pos_inicial,v_diferencia);
     v_codigo:= trim(v_codigo);
     v_lugar:= 'Insertar en Log';
    --**************************************
    begin
        insert into ba_log_swift(mensaje,gpi,codigo,archivo)
        values(p_mensaje,v_es_gpi,v_codigo,p_archivo);
        commit;
    exception
       when others then
           v_lugar:= 'Error al Insertar en Log:'||sqlerrm;
           v_resultado:='Error al grabar-Arch.: '||p_archivo||' '||sqlerrm;
           lp_act_log(v_codigo,v_resultado);
           return v_resultado;
    end;
    --Ceramos variables
    v_pos_inicial:=null;
    v_pos_final:=null;
    v_diferencia:= null;
    v_valor:=null;
    --******************************
    v_lugar:= 'Validar Mensajeria';
    if p_mensaje is null then
        v_resultado:='La mensajeria no puede ser nula-Arch.: '||p_archivo;
        if v_resultado is not null then
             lp_act_log(v_codigo,v_resultado);
             return(v_resultado);
        end if;
    end if;
    Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
    --Se borra la tabla temporal
    delete from lc_swift_tmp;
    commit;
    v_lugar:= 'Obtener Longitud del mensaje';
    v_longitud:= length(p_mensaje);
    v_n_fin_cabecera:= instr(p_mensaje,v_id_fin_cabecera,1,2) ;
    v_n_ini_pie:= instr(p_mensaje,v_id_ini_pie)-1 ;
    --Pie de Mensaje
    v_lugar:= 'Obtener pie del mensaje';
    v_diferencia:= (v_longitud +1) - v_n_ini_pie;
    v_pie:= trim(substr(p_mensaje, v_n_ini_pie,v_diferencia));
    --Cabecera
    v_lugar:= 'Obtener Cabecera del mensaje';
    v_pos_inicial:=1;
    v_pos_final:= (v_n_fin_cabecera)+3;
    v_cabecera:=  substr(p_mensaje, v_pos_inicial,v_pos_final);
    --Se graba Cabecera
    v_lugar:= 'Grabar Cabecera';
    lp_ins_tmp(v_cabecera);
    if v_resultado is not null then
         v_resultado:= trim(v_resultado)||' Cab.-Arch.:'||p_archivo;
         lp_act_log(v_codigo,v_resultado);
         return(v_resultado);
    end if;
    v_lugar:= 'Obtener Ocurrencia';
    --Cuerpo del Mensaje
    v_ocurrencias:=FU_OBT_OCURRENCIAS(p_mensaje, v_salto);
    v_ocurrencias:=v_ocurrencias -1;
    v_contador:=1;
    v_texto:= p_mensaje;
     --
    FOR i in 1..v_ocurrencias LOOP
       if v_contador=1 then
          v_lugar:= 'Inicio de Cuerpo Ini.';
          v_pos_inicial:= instr(v_texto,v_salto,1)+1 ;
          v_pos_final:=instr(v_texto,v_salto,1,v_contador+1) ;
          v_diferencia:= v_pos_final -v_pos_inicial;
          v_aux_dif := instr(v_texto,v_salto1,1,v_contador+1) ;
          if v_aux_dif <> 0 then
             v_valor:= substr(v_texto, v_pos_inicial,(v_diferencia-1));
          else
             v_valor:= substr(v_texto, v_pos_inicial,(v_diferencia));
          end if;
          v_valor:= trim(v_valor);
          v_espacio:= INSTR(v_valor,' ',1,1);
          v_long_cad:= length(v_valor);
          if v_espacio >0 and  v_long_cad= v_espacio then
             v_valor := substr(v_valor,1,(INSTR(v_valor,' ',1,1)-1));
          end if;
          --Se graba detalle de la mensajeria
          v_lugar:= 'Grabar Cuerpo Ini.';
          if length(v_valor)>0 then
              lp_ins_tmp(v_valor);
          end if;
          if v_resultado is not null then
             v_resultado:= trim(v_resultado)||' Body.-Arch.:'||p_archivo;
             lp_act_log(v_codigo,v_resultado);
             return(v_resultado);
          end if;

       else
          v_lugar:= 'Inicio de Cuerpo';
          v_pos_inicial:= instr(v_texto,v_salto,1,v_contador)+1 ;
          v_pos_final:=instr(v_texto,v_salto,1,v_contador+1) ;
          v_diferencia:= v_pos_final -v_pos_inicial;
          v_aux_dif := instr(v_texto,v_salto1,1,v_contador+1) ;
          if v_aux_dif <> 0 then
             v_valor:= substr(v_texto, v_pos_inicial,(v_diferencia-1));
          else
             v_valor:= substr(v_texto, v_pos_inicial,(v_diferencia));
          end if;
          v_valor:= trim(v_valor);
          v_espacio:= INSTR(v_valor,' ',1,1);
          v_long_cad:= length(v_valor);
          if v_espacio >0 and  v_long_cad= v_espacio then
             v_valor := substr(v_valor,1,(INSTR(v_valor,' ',1,1)-1));
          end if;
          v_lugar:= 'Grabar Cuerpo';
          --Se graba detalle de la mensajeria
          if length(v_valor)>0 then
             lp_ins_tmp(v_valor);
          end if;   
          if v_resultado is not null then
             v_resultado:= trim(v_resultado)||' Body-Arch.:'||p_archivo;
             lp_act_log(v_codigo,v_resultado);
             return(v_resultado);
          end if;
       end if;
       v_contador:= nvl(v_contador,0)+1;
    END LOOP;
    --Se graba pie de la mensajeria
    v_lugar:= 'Grabar Pie';
    lp_ins_tmp(v_pie);
    if v_resultado is not null then
       v_resultado:= trim(v_resultado)||' Pie-Arch.:'||p_archivo;
       lp_act_log(v_codigo,v_resultado);
       return(v_resultado);
    end if;

    --*** Se llama al proceso que inserta en lc_transferencias ***
     v_lugar:= 'Obtener Nro de Lote';
     v_nro_sec_lote:= to_number (fug_obt_pardinamico('SIG_NRO_SEC_LOTE'));
     v_lugar:= 'Insertar en lc_transferencias:'||v_nro_sec_lote;
     Begin
       v_can_reg_procesados:= FUL_PRO_TRA_RECIBIDAS(v_nro_sec_lote);
     exception
       when others then
         lp_act_log(v_codigo,substr(sqlerrm,1,2000));
         v_resultado:=substr(sqlerrm,1,2000);
         return v_resultado;
     end;
     v_lugar:= 'Resultado de Insercion:'||v_can_reg_procesados;
     If nvl(trim(v_can_reg_procesados),'000001')='000001' then
        lp_act_log(v_codigo,'ok');
     end if;
      if trim(v_can_reg_procesados) ='000001' then
         update ge_par_dinamicos a
           set a.val_parametro= nvl(v_nro_sec_lote,0) +1
             where a.parametro='SIG_NRO_SEC_LOTE';
           commit;
           v_resultado:='00';
      end if;
    --***Fin de llamado ***
  return(v_resultado);
exception
  when others then
       raise_application_error(-20000,'Error-FUL_INS_TRA_RECIBIDAS:'||v_lugar||'-'||sqlerrm);
end FUL_INS_TRA_RECIBIDAS;
/

