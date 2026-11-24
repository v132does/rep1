create or replace function it.fug_pro_msj_mt940 (p_mensaje in long) return varchar2 is
-------------------------------------------------------
--Procesa / alza los archivos MT940
--MT940 son movimientos de extractos en formato SWIFT
-------------------------------------------------------
--Variables--
g_lugar varchar2(4000);
v_cod_mensaje ge_snp_msj_mt940_tmp.cod_mensaje%type;
v_nro_cuenta ge_snp_msj_mt940.nro_cuenta%type;

procedure pr_pro_des_lin_mt940 is 
--Variables
v_pos_inicial number;
v_pos_final   number;
v_contador    number;
v_procesar    varchar2(1);
v_linea       varchar2(4000);

--Cursor--
cursor c_men_detalles is
       select x.*, x.rowid registro
         from ge_snp_msj_mt940_tmp x
        where x.tipo = 'D'
          and substr(x.linea,1,1) <> ':'
        order by x.nro_orden;

cursor c_men_det_86 is
       select x.*, x.rowid registro
         from ge_snp_msj_mt940_tmp x
        where x.tipo = 'D'
          and substr(x.linea,1,4) = ':86:'
        order by x.nro_orden;

--Programa Principaal--
BEGIN
  g_lugar := 'Desglose de Linea (pr_pro_des_lin_mt940)';
  --Eliminar tabla temporal--
  delete from GE_SNP_MSJ_MT940_TMP;  
  
  --Inicializar variables--
  v_pos_inicial := 1;
  v_pos_final := null;
  v_contador := 0;
  v_procesar := 'S';
  v_linea := null;
  
  --Traer la Secuencia Unica del cod_mensaje--
  select S_COD_MEN_SNP_MT940.NEXTVAL
    into v_cod_mensaje
    from dual;
  
  --Ciclo que recorre todo el mensaje--
  WHILE (v_procesar = 'S')
  LOOP
          v_contador := v_contador + 1;
          if v_contador = 1 then
             v_pos_final := instr(p_mensaje,'*',v_pos_inicial);
             v_linea := substr(p_mensaje,v_pos_inicial,(v_pos_final-v_pos_inicial));
             ----
             insert into ge_snp_msj_mt940_tmp
             (cod_mensaje, linea, mensaje, nro_orden, pos_inicial, pos_final)
             values
             (v_cod_mensaje, v_linea, p_mensaje, v_contador, v_pos_inicial, v_pos_final);
             v_pos_inicial := nvl(v_pos_final,0) + 1;
          else
             v_pos_final := instr(p_mensaje,'*',v_pos_inicial);
             v_linea := substr(p_mensaje,v_pos_inicial,(v_pos_final-v_pos_inicial));
             --Verificar si va a finalizar la carga--
             if substr(p_mensaje,v_pos_final+1,2) = '-}' then
                v_procesar := 'N';
                insert into ge_snp_msj_mt940_tmp
                (cod_mensaje, linea, mensaje, nro_orden, pos_inicial, pos_final)
                values
                (v_cod_mensaje, v_linea, p_mensaje, v_contador, v_pos_inicial, v_pos_final-3);
                
                --Ultima parte--
                insert into ge_snp_msj_mt940_tmp
                (cod_mensaje, linea, mensaje, nro_orden, pos_inicial, pos_final)
                values
                (v_cod_mensaje, '-}', p_mensaje, v_contador+1, v_pos_inicial, v_pos_final);
             else
                insert into ge_snp_msj_mt940_tmp
                (cod_mensaje, linea, mensaje, nro_orden, pos_inicial, pos_final)
                values
                (v_cod_mensaje, v_linea, p_mensaje, v_contador, v_pos_inicial, v_pos_final);
                
                v_pos_inicial := nvl(v_pos_final,0) + 1;
             end if;
          end if;
      END LOOP;

      --Actualizar Cabeceras--
      update ge_snp_msj_mt940_tmp x
         set x.tipo = 'C'
       where ((substr(x.linea,1,4) in (':20:',':25:')) or (substr(x.linea,1,5)in (':28C:',':60F:',':62F:')));

      --Actualizar Detalles--
      update ge_snp_msj_mt940_tmp x
         set x.tipo = 'D'
       where x.tipo is null;

      --Actualizar Lineas de Referencia a Detalles--
      for det in c_men_detalles loop
          update ge_snp_msj_mt940_tmp x
             set x.lin_referencia = (select max(y.nro_orden)
                                       from ge_snp_msj_mt940_tmp y
                                      where y.tipo = 'D'
                                        and substr(y.linea,1,1) = ':'
                                        and y.nro_orden < x.nro_orden)
           where x.rowid = det.registro;
      end loop;
      
      --Actualizar Lineas de Referencia a Detalles 86--
      for det in c_men_det_86 loop
          update ge_snp_msj_mt940_tmp x
             set x.lin_referencia = (select max(y.nro_orden)
                                       from ge_snp_msj_mt940_tmp y
                                      where y.tipo = 'D'
                                        and substr(y.linea,1,4) = ':61:'
                                        and y.nro_orden < x.nro_orden)
           where x.rowid = det.registro;
      end loop;
      
  end;

procedure pr_pro_ins_cab_mt940 is
--Variables--
reg ge_snp_msj_mt940%rowtype;
v_contador number;
v_mensaje ge_snp_msj_mt940_tmp.mensaje%type;

--Cursor registros de cabecera--
cursor c_cab_mt940 is
       select x.*, x.rowid registro
         from ge_snp_msj_mt940_tmp x
        where x.cod_mensaje = v_cod_mensaje
          and x.tipo = 'C'; --Cabecera de Extracto--
begin
  g_lugar := 'Carga de Cabecera (pr_pro_ins_cab_mt940)';
  v_mensaje := null;
  v_contador := 0;
  for cab in c_cab_mt940 loop
      v_contador := nvl(v_contador,0) + 1;
      if v_contador = 1 then
         --Guardar el Mensaje--
         v_mensaje := cab.mensaje;
      end if;
      reg.cod_mensaje := cab.cod_mensaje;
      if substr(cab.linea,1,4) = ':20:' then
        --Referencia--
        reg.referencia := substr(cab.linea,5);
      elsif substr(cab.linea,1,4) = ':25:' then
        --Nro. de Cuenta--
        reg.nro_cuenta := substr(cab.linea,5);
        v_nro_cuenta := reg.nro_cuenta;
      elsif substr(cab.linea,1,5) = ':28C:' then
        --Nro. de Extracto / Nro. de Hoja--
        reg.nro_extracto := substr(cab.linea,6,(instr(cab.linea,'/',6)-6));
        reg.nro_hoja := substr(cab.linea,instr(cab.linea,'/',6)+1);
      elsif substr(cab.linea,1,5) = ':60F:' then
         --Fecha Inicial, Moneda, Saldo Inicial--
         reg.fec_inicial := to_date(substr(cab.linea,7,6),'rrmmdd');
         reg.cod_moneda := substr(cab.linea,13,3);
         reg.sal_inicial := to_number(replace(substr(cab.linea,16),',','.'));
                            --substr(cab.linea,16,15);
      elsif substr(cab.linea,1,5) = ':62F:' then
         ----Fecha Final, Moneda, Saldo Final--
         reg.fec_final := to_date(substr(cab.linea,7,6),'rrmmdd');
                          --to_date(substr(msj.texto,6,6),'rrmmdd');
         reg.sal_final := to_number(replace(substr(cab.linea,16),',','.'));
                          --substr(cab.linea,16,15);
      end if;
  end loop;
  --Insertar el Mensaje--
  insert into ge_snp_msj_mt940
  (cod_mensaje, referencia, nro_cuenta, nro_extracto, nro_hoja, 
   fec_inicial, cod_moneda, sal_inicial, fec_final, sal_final, mensaje)
  values
  (reg.cod_mensaje, reg.referencia, reg.nro_cuenta, reg.nro_extracto, reg.nro_hoja, 
   reg.fec_inicial, reg.cod_moneda, reg.sal_inicial, reg.fec_final, reg.sal_final, v_mensaje);
end;

procedure pr_pro_ins_det_mt940 is
--Variables--
reg ge_snp_msj_mt940_det%rowtype;
v_contador number;
v_pos_coma number;
v_pos_divi number;
v_pos_ini_ref number;
v_referencia varchar2(4000);
v_nro_ord_61 number;
v_nro_ord_86 number;
v_dat_adi_operacion varchar2(4000);
v_dat_adi_otros varchar2(4000);

--Cursor registros de detalle--
cursor c_det_mt940 is
       select t.*, t.rowid registro 
         from ge_snp_msj_mt940_tmp t
        where t.tipo = 'D'
          and t.lin_referencia is null
          and substr(t.linea,1,4) = ':61:'
        order by nro_orden;
--Cursor de detalles lineas :86:--
cursor c_det_mt940_86 is
       select t.*, t.rowid registro 
         from ge_snp_msj_mt940_tmp t
        where t.tipo = 'D'
          and t.lin_referencia = v_nro_ord_61
        order by nro_orden;

--Cursor de detalles adicionales--
cursor c_det_mt940_86_otros is
       select t.*, t.rowid registro 
         from ge_snp_msj_mt940_tmp t
        where t.tipo = 'D'
          and t.lin_referencia = v_nro_ord_86
        order by nro_orden;
 
begin
  g_lugar := 'Carga de Detalle (pr_pro_ins_det_mt940)';
  v_contador := 0;
  for det in c_det_mt940 loop
      reg.cod_mensaje := null;
      reg.fecha := null;
      reg.tip_movimiento := null;
      reg.monto := null;
      reg.ind_referencia := null;
      reg.cod_msj_swift := null;
      reg.nro_referencia := null;
      reg.nro_identificador := null;
      reg.dat_adi_operacion := null;
      reg.dat_adi_otros := null;
            
      v_contador := nvl(v_contador,0) + 1;
      --Codigo de Mensaje para relacionar con cabecera--
      reg.cod_mensaje := det.cod_mensaje;
      --Fecha de Movimiento--
      reg.fecha := to_date(substr(det.linea,5,6),'rrmmdd');
      --Tipo de Movimiento--
      reg.tip_movimiento := substr(det.linea,11,1);
      
      v_pos_coma := instr(det.linea,',',12);
      
      if ((fug_val_es_numerico(substr(det.linea,v_pos_coma+1,1)) = 'S') and 
          (fug_val_es_numerico(substr(det.linea,v_pos_coma+2,1)) = 'S')) then
          reg.monto := to_number(replace(substr(det.linea,12,(v_pos_coma+2)-12),',','.'));
          v_pos_ini_ref := (v_pos_coma+2) + 1;
      else
          reg.monto := to_number(replace(substr(det.linea,12,v_pos_coma-12),',','.'));
          v_pos_ini_ref := v_pos_coma + 1;
      end if;
      --Cargar referencia (Posterior al monto)
      v_referencia := substr(det.linea,v_pos_ini_ref);
      reg.ind_referencia := substr(v_referencia,1,1);
      --Verificar desglose de referencia--
      if reg.ind_referencia = 'S' then
        reg.cod_msj_swift := substr(v_referencia,2,3);
        v_pos_divi := instr(v_referencia,'//',1);
        reg.nro_referencia := substr(v_referencia,5,v_pos_divi-5);
        reg.nro_identificador := substr(v_referencia,v_pos_divi+2);       
      else
        v_pos_divi := instr(v_referencia,'//',1);
        reg.nro_referencia := substr(v_referencia,1,v_pos_divi-1);
        reg.nro_identificador := substr(v_referencia,v_pos_divi+2);
      end if;
      
      --Buscar Datos Adicionales 86--
      v_nro_ord_61 := det.nro_orden;
      v_dat_adi_operacion := null;
      for det86 in c_det_mt940_86 loop
          v_nro_ord_86 := det86.nro_orden;
          v_dat_adi_operacion := v_dat_adi_operacion||'*'||det86.linea;
          v_dat_adi_otros := null;
          for detot in c_det_mt940_86_otros loop
              v_dat_adi_otros := v_dat_adi_otros||'*'||detot.linea;
          end loop;
          if v_dat_adi_otros is not null then
             v_dat_adi_otros := v_dat_adi_otros||'*';
          end if;
      end loop;
      if v_dat_adi_operacion is not null then
         v_dat_adi_operacion := v_dat_adi_operacion||'*';
      end if;    
      reg.dat_adi_operacion := v_dat_adi_operacion;
      reg.dat_adi_otros := v_dat_adi_otros;
      
      --Insertar el Mensaje--
      insert into ge_snp_msj_mt940_det
      (cod_mensaje, fecha, tip_movimiento, monto, ind_referencia, cod_msj_swift, 
      nro_referencia, nro_identificador, dat_adi_operacion, dat_adi_otros, nro_cuenta)
      values
      (reg.cod_mensaje, reg.fecha, reg.tip_movimiento, reg.monto, reg.ind_referencia, reg.cod_msj_swift, 
      reg.nro_referencia, reg.nro_identificador, reg.dat_adi_operacion, reg.dat_adi_otros, v_nro_cuenta);       
  end loop;
end;

BEGIN
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
  prg_cre_savepoint('mt940');
  pr_pro_des_lin_mt940;
  pr_pro_ins_cab_mt940;
  pr_pro_ins_det_mt940;
  --Retorno de Mensaje--
  return '00' || '|' || 'MT940' || '|' || v_cod_mensaje || ' - Procesado OK';
exception
when others then
     prg_rol_savepoint('mt940');
     return 99 || '|' || 'MT103' || '|' || g_lugar || ' - ' || SQLERRM;
END;
/

