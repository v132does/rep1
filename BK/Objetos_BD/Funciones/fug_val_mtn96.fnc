CREATE OR REPLACE FUNCTION IT.FUG_VAL_MTN96(p_texto in clob)
RETURN NUMBER
IS
  v_return NUMBER:=0;

  v_nro_ref_externa ge_snp_transferencias.nro_referencia%TYPE;
  v_cod_swift       ge_snp_transferencias.cod_msj_swift%TYPE;
  v_sub_tipo_mt     varchar2(40);
  v_tag_96          ge_snp_mensajes.nro_referencia%type;
  v_tag_20          ge_snp_mensajes.nro_referencia%type;


  PROCEDURE pr_get_val_tags_MTN96 (p_texto in clob,
                           p_nro_ref_externa out ge_snp_transferencias.nro_referencia%TYPE,
                           p_cod_swift       out ge_snp_transferencias.cod_msj_swift%TYPE,
                           p_sub_tipo_mt     out varchar2,
                           p_tag_96          out ge_snp_mensajes.nro_referencia%TYPE,
                           p_tag_20          out ge_snp_mensajes.nro_referencia%TYPE)
    IS

       r_sb_snp_tmp_mensajes sb_snp_mensajes_tmp%rowtype := null;
       v_cod_mensaje         sb_snp_tip_mensajes.cod_mensaje%type;
       v_can_lineas          number;
       v_det_campo           sb_snp_campos.campo%type;
       b_tag_21              BOOLEAN := FALSE; --Flag para verificar que no se haya encontrado ya el Tag 21, en caso de que exista mas de uno en el Swift
       v_tag_20              ge_snp_mensajes.nro_referencia%type;
       v_tag_96              ge_snp_mensajes.nro_referencia%type;
    begin


       begin
         --obtengo el mensaje, si no encuentra esquematizado igual se debe registrar en GE_SNP_MENSAJES
         v_cod_mensaje := pao_pmt.fu_obt_cod_mensaje(p_texto);
       exception  when others then
         raise;
       end;
       --Obtengo el campo PK del Detalle
       select max(d.campo)
         into v_det_campo
         from sb_snp_campos d
        where d.cod_mensaje = v_cod_mensaje
          and d.orden = (select min(orden)
                           from sb_snp_campos
                          where cod_mensaje = d.cod_mensaje
                            and ind_detalle = d.ind_detalle)
          and d.ind_detalle = 'S';
       --Se cuentan la cantidad de líneas para el recorrido
       select count(*)
         into v_can_lineas
         from table(fug_obt_tab_registro(replace(p_texto, chr(13)), chr(10)));

       -- Recorro las lineas del swift
       for i in 1..v_can_lineas loop
          r_sb_snp_tmp_mensajes.cod_mensaje := v_cod_mensaje;
          r_sb_snp_tmp_mensajes.orden := i;
          r_sb_snp_tmp_mensajes.valor := trim(pao_pmt.fu_obt_linea(p_texto, r_sb_snp_tmp_mensajes.orden));
          r_sb_snp_tmp_mensajes.campo := nvl(pao_pmt.fu_obt_campo(r_sb_snp_tmp_mensajes.valor), r_sb_snp_tmp_mensajes.campo);
          if r_sb_snp_tmp_mensajes.campo = pao_pmt.fu_obt_campo(r_sb_snp_tmp_mensajes.valor) then
             r_sb_snp_tmp_mensajes.nro_linea := 1;
             if nvl(v_det_campo, '*') = r_sb_snp_tmp_mensajes.campo then
                r_sb_snp_tmp_mensajes.nro_detalle := nvl(r_sb_snp_tmp_mensajes.nro_detalle, 0) + 1;
             end if;
          else
             r_sb_snp_tmp_mensajes.nro_linea := r_sb_snp_tmp_mensajes.nro_linea + 1;
          end if;
          r_sb_snp_tmp_mensajes.valor := trim(replace(r_sb_snp_tmp_mensajes.valor, ':'||r_sb_snp_tmp_mensajes.campo||':'));

          -- Si la linea es uno de los Tags deseados, se setea la variable de salida
          if  r_sb_snp_tmp_mensajes.campo = '21' and not b_tag_21 then
            p_nro_ref_externa := r_sb_snp_tmp_mensajes.valor;
            b_tag_21 := TRUE; --Si se encontro el Tag 21 se marca el flag, dado que puede existir otro en los 296
          elsif r_sb_snp_tmp_mensajes.campo = '11R'  and r_sb_snp_tmp_mensajes.nro_linea = 1 then
            p_cod_swift := r_sb_snp_tmp_mensajes.valor;
          elsif r_sb_snp_tmp_mensajes.campo = '76' and r_sb_snp_tmp_mensajes.orden =  5 then
            IF v_cod_mensaje = 'MTn96/AUTH' THEN --TRFS-1426
               p_sub_tipo_mt := 'AUTH';         
            ELSIF v_cod_mensaje = 'MTn96/CANC' THEN
               p_sub_tipo_mt := 'CANC'; --Los subtipos OK o ERRC se manejan igual TCE-206
            ELSE
               p_sub_tipo_mt := substr(r_sb_snp_tmp_mensajes.valor,1,4);
            END IF;
            
          elsif r_sb_snp_tmp_mensajes.campo = '20' and r_sb_snp_tmp_mensajes.valor like '%/%' then--TCE-187
              v_tag_96 := substr(r_sb_snp_tmp_mensajes.valor,(instr(r_sb_snp_tmp_mensajes.valor, '/') + 1));
              p_tag_96 := v_tag_96;
          elsif r_sb_snp_tmp_mensajes.campo = '20' and r_sb_snp_tmp_mensajes.valor not like '%/%' then --TCE-187
              v_tag_20 := substr(r_sb_snp_tmp_mensajes.valor,(instr(r_sb_snp_tmp_mensajes.valor, '/') + 1));
              p_tag_20 := v_tag_20;
          end if;
       end loop;


    END pr_get_val_tags_MTN96;
BEGIN

  /* Proceso para validar existencia de la referencia de un 196 antes de intentar procesar el archivo
     Creado por TRFS-1088 PHT
     Return:
       Mayor a 0 - Existe la referencia del MTN96
       Igual a 0 - No existe la referencia
       Menor a 0 - Se detecto algun error durante la validacion
  */

  --Obtengo los valores del MTN96
  pr_get_val_tags_MTN96 (p_texto => replace(p_texto,pas_snp.fu_obt_sal_socket,pas_snp.fu_obt_salto),
                   p_nro_ref_externa => v_nro_ref_externa,
                   p_cod_swift => v_cod_swift,
                   p_sub_tipo_mt  => v_sub_tipo_mt,
                   p_tag_96          => v_tag_96,
                   p_tag_20          => v_tag_20 );


  --Dependiendo el subtipo del 196, busco que exista su referencia en el Core
  IF v_sub_tipo_mt = 'NETS' and v_cod_swift <> 104  THEN
    select count(*)
    INTO v_return
    from ge_snp_transferencias ge
    where ge.nro_lote = to_char(v_nro_ref_externa)
      and ge.cod_msj_swift = v_cod_swift
      and ge.fec_recepcion is null
      and ge.estado in ('A','R')
      and ge.situacion = 'O';
  ELSIF v_sub_tipo_mt in ('NETR', 'NETA', 'NETL') THEN
    select count(*)
    INTO v_return
    from ge_snp_transferencias ge
    where ge.nro_lote = to_char(v_nro_ref_externa)
      and ge.cod_msj_swift = v_cod_swift
      and ge.fec_valor <= pag_cal.fu_obt_fec_actual(1);
  ElSIF v_sub_tipo_mt in ('ERRC','ERRP') AND v_cod_swift in (102, 104) THEN
    select count(*)
    INTO v_return
    from ge_snp_transferencias ge
    where ge.nro_lote = to_char(v_nro_ref_externa)
      and ge.cod_msj_swift = v_cod_swift;
  ElSIF v_sub_tipo_mt in ('AUTH') THEN --TRFS-1426
    v_return := 1; --Los tipo AUTH no son procesados actualmente en el core
  
  ElSIF v_cod_swift = 104 then----TCE-187
  
    select count(*)
      INTO v_return
      from ge_snp_transferencias ge
     where ge.nro_lote = to_char(v_nro_ref_externa)
       and ge.cod_msj_swift = v_cod_swift
       and ge.fec_recepcion is not null;
       
   if v_return = 0 then
      select count(*)
      INTO v_return
        from ge_snp_transferencias ge
       where ge.nro_lote = to_char(v_tag_20)
         and ge.cod_msj_swift = v_cod_swift
         and ge.fec_recepcion is not null;
    end if;  
    
  ELSIF v_cod_swift = 103 AND v_tag_96 = 196 then--TCE-187
    if v_sub_tipo_mt in ( 'WAIT' ,'ERRP' ) then
      select count(*)
        INTO v_return
        from ge_snp_transferencias t
       where t.nro_referencia = v_nro_ref_externa;
        if v_return = 0 then--respuesta MT 195 
          select count(*)
        INTO v_return
        from ge_snp_mensajes t
       where t.nro_referencia = to_char(v_nro_ref_externa);
        end if; 
    elsif  v_sub_tipo_mt in ( 'INAC' ,'EXEC' ) then
       --Estos subtipos son de caracter informativo y no se procesan por lo cual no hace falta validarlos
       v_return := 1; --TCE-206
    elsIF  v_sub_tipo_mt = 'CANC' then --CANC/OK --TCE-206
      select count(*)
        INTO v_return
        from ge_snp_mensajes t
       where t.nro_referencia = to_char(v_nro_ref_externa);
    else --TCE-206 Cualquier otro 103 196 se busca la transf por tag 21
      select count(*)
      INTO v_return
      from ge_snp_transferencias t
      where t.nro_referencia  = v_nro_ref_externa;          
    end if;  
    
  ELSE
    select count(*)
    INTO v_return
    from ge_snp_transferencias t
    where t.nro_referencia  = v_nro_ref_externa;
     if v_return = 0 then--TCE-187
       select count(*)
        INTO v_return
        from ge_snp_mensajes t
       where t.nro_referencia = to_char(v_nro_ref_externa);
     end if; 
  END IF;

  --Si la referencia existe, se retornara un valor mayor a 0
  RETURN v_return;

EXCEPTION WHEN OTHERS THEN
    RETURN -1;
END FUG_VAL_MTN96;
