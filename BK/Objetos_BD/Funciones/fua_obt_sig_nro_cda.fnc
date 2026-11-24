CREATE OR REPLACE FUNCTION IT.FUA_OBT_SIG_NRO_CDA
 (P_COD_MODULO IN AH_CER_GRUPOS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN AH_CER_GRUPOS.COD_MODALIDAD%TYPE
 ,P_MONEDA IN AH_CER_GRUPOS.TIP_MONEDA%TYPE
 ,P_COD_OFICINA IN AH_CER_GRUPOS.COD_OFICINA%TYPE
 ,P_SERIE IN AH_CER_GRUPOS.SERIE%TYPE
 ,P_USUARIO IN BA_USUARIOS.COD_PERSONA%TYPE
 )
 RETURN NUMBER
 IS
  v_sig_nro         ah_cer_grupos.ult_nro_emitido%type;
  v_anulado         varchar2(1) := 'N';
  v_emitido         varchar2(1) := 'N';
  v_cod_mon_local   varchar2(20);
  v_cod_mon_usd     varchar2(3);
  v_cod_mon_eur     varchar2(3);
  v_cer_grupo       number(6);
  record_locked     exception;
  pragma exception_init (record_locked, -54);
  ---
  cursor c_inv_usuario is
  select cod_cer_grupo, 
         cod_modulo, 
         cod_modalidad,
         tip_moneda,
         cod_oficina, 
         serie, 
         nro_inicial, 
         nro_final
    from ah_cer_grupos
   where cod_modulo = p_cod_modulo
     and cod_modalidad = p_cod_modalidad
     and tip_moneda = p_moneda
     and cod_oficina = p_cod_oficina
     and serie = p_serie
     and cod_usu_responsable = p_usuario
     and can_disponibles > 0
     and estado = 'A'
     order by nro_inicial asc;

begin
 -- Determinar lzas monedas
 SELECT cod_mon_local, cod_mon_fuerte, 'EUR'
   INTO v_cod_mon_local, v_cod_mon_usd, v_cod_mon_eur 
   FROM ge_par_generales;
 
 -- cursor que recorre los lotes activos del usuario
  for x in c_inv_usuario loop
    BEGIN
      -- Seleccionamos para bloquear
      SELECT cod_cer_grupo 
        INTO x.cod_cer_grupo 
        FROM ah_cer_grupos
       WHERE cod_cer_grupo = x.cod_cer_grupo
      FOR UPDATE NOWAIT;
    EXCEPTION
      WHEN record_locked THEN
          -- Si el lote actual está bloqueado, pasamos al siguiente lote
          CONTINUE; 
    END;
        
    --  recorre 1 a 1 los cartones del lote, hasta encontrar un numero disponible (no emitido ni anulado)
    FOR nro_carton IN x.nro_inicial .. x.nro_final LOOP
      DECLARE
        v_moneda VARCHAR2(100);
        BEGIN
         IF x.tip_moneda = 'L' THEN
             v_moneda := '''' || v_cod_mon_local || '''';
         ELSE
             v_moneda := '''' || v_cod_mon_usd || ''',''' || v_cod_mon_eur || '''';
         END IF;
                 
         v_anulado := 'N';
         v_emitido := 'N';
         v_sig_nro := NULL;

         -- 1. Verificacion anulados
         BEGIN
           EXECUTE IMMEDIATE 'SELECT ''S'' FROM ah_cer_anulados WHERE serie = :1 AND cod_modulo = :2 AND cod_modalidad = :3 AND nro_certificado = :4 AND cod_moneda IN (' || v_moneda || ')'
               INTO v_anulado
               USING x.serie, x.cod_modulo, x.cod_modalidad, nro_carton;
            v_anulado := 'S';
          EXCEPTION
            WHEN NO_DATA_FOUND THEN 
              v_anulado := 'N';
            WHEN TOO_MANY_ROWS THEN 
              v_anulado := 'S';
          END;
                  
          -- 2. Verificacion de emitidos
          IF v_anulado = 'N' THEN
             BEGIN
                EXECUTE IMMEDIATE 'SELECT ''S'' FROM ah_cta_certificados WHERE serie = :1 AND cod_modulo = :2 AND cod_modalidad = :3 AND nro_certificado = :4 AND cod_moneda IN (' || v_moneda || ')'
                    INTO v_emitido
                    USING x.serie, x.cod_modulo, x.cod_modalidad, nro_carton;
                v_emitido := 'S';
             EXCEPTION
                WHEN NO_DATA_FOUND THEN 
                  v_emitido := 'N';
                WHEN TOO_MANY_ROWS THEN 
                  v_emitido := 'S';
             END;
          END IF;

          -- 3. Asignacion y Salida
          IF v_emitido = 'N' AND v_anulado = 'N' THEN
             v_sig_nro   := nro_carton;
             v_cer_grupo := x.cod_cer_grupo; 
             EXIT; -- Salimos del bucle
          END IF;
        END; -- Fin del bloque de busqueda por número
    end loop;
    
     -- si encuentra un numero disponible, sale del loop principal
    if v_sig_nro is not null then
       exit;
    end if;

  end loop;
  
  -- Manejo de Lotes Agotados
  if nvl(v_sig_nro,0) = 0 then
    raise_application_error(-20000,' Sin nro de CDA activo/disponible para '
                           ||' Modalidad:'|| p_cod_modalidad
                           ||', Moneda:'  || p_moneda
                           ||', Oficina:' || fue_obt_des_oficina(p_cod_oficina)
                           ||', Serie:'   || p_serie
                           ||', usuario:' || p_usuario);
  end if;
     
  /** Actualiza el ultimo numero emitido **/
  update ah_cer_grupos
     set ult_nro_emitido = v_sig_nro,
         can_emitidos    = nvl(can_emitidos,0) + 1,
         can_disponibles = nvl(can_disponibles,0) - 1
   where cod_cer_grupo = v_cer_grupo;
 
  return v_sig_nro;
  
exception
  when no_data_found then
    raise_application_error(-20000,'No existe siguiente numero de CDA para asignar.');
  when record_locked then
    raise_application_error(-20000,'Numero de CDA bloqueado por otro usuario');
  when others then
    if sqlcode <= -20000 then
       raise;
    else
       raise_application_error(-20000,'Error al Obtener siguiente nro.CDA:'||sqlerrm);
    end if;
end;
/
