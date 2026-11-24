CREATE OR REPLACE PROCEDURE IT.PRJ_OBT_DAT_MOV_PRODEP (p_nro_referencia in out cj_mov_prodep.nro_referencia%type, -- número de referencia en prodep
                                                    p_fecha          in     cj_mov_prodep.fecha%type, -- Fecha del Movimiento
                                                    p_hora           in     cj_mov_prodep.hora%type, -- Hora del Movimiento
                                                    p_cod_usuario    in out cj_mov_prodep.cod_usuario%type, -- Usuario 
                                                    p_cod_moneda     out    cj_mov_prodep.cod_moneda%type, -- codigo de la moneda
                                                    p_nro_cuenta     out    cj_mov_prodep.nro_cuenta%type, -- número de cuenta 
                                                    p_nro_documento  out    cj_mov_prodep.nro_documento%type, -- número de boleta o documento
                                                    p_nro_caja       in out cj_mov_prodep.nro_caja%type, -- número de caja 
                                                    p_monto          in out cj_mov_prodep.monto%type, -- monto del movimiento
                                                    p_estado         out    cj_mov_prodep.estado%type -- estado del movimiento
                                                    ) IS
  v_fecha        cj_mov_prodep.fecha%type;
  v_cod_usuario  cj_mov_prodep.cod_usuario%type;
  v_hora         cj_mov_prodep.hora%type;                                                                                                        
BEGIN
  IF p_nro_referencia IS NOT NULL THEN  
    BEGIN
      SELECT p.cod_moneda, p.nro_cuenta, p.nro_documento, p.nro_caja, p.fecha, p.cod_usuario, p.hora, SUM(p.monto)
        INTO p_cod_moneda, p_nro_cuenta, p_nro_documento, p_nro_caja, v_fecha, v_cod_usuario, v_hora, p_monto
        FROM cj_mov_prodep p
       WHERE p.nro_referencia = p_nro_referencia
         AND p.estado <> 'R'
       GROUP BY p.cod_moneda, p.nro_cuenta, p.nro_documento, p.nro_caja, p.fecha, p.cod_usuario, p.hora;
    EXCEPTION
      WHEN TOO_MANY_ROWS THEN
        BEGIN
          SELECT p.cod_moneda, p.nro_cuenta, p.nro_documento, p.nro_caja, p.fecha, p.cod_usuario, p.hora, SUM(p.monto)
            INTO p_cod_moneda, p_nro_cuenta, p_nro_documento, p_nro_caja, v_fecha, v_cod_usuario, v_hora, p_monto
            FROM cj_mov_prodep p
           WHERE p.nro_referencia = p_nro_referencia
             AND p.estado <> 'R'
             AND p.monto = p_monto
           GROUP BY p.cod_moneda, p.nro_cuenta, p.nro_documento, p.nro_caja, p.fecha, p.cod_usuario, p.hora;
        EXCEPTION
          WHEN OTHERS THEN   
            p_cod_moneda    := null;
            p_nro_cuenta    := null;
            p_nro_documento := null;
            p_nro_caja      := null;
            v_fecha         := null;
            v_cod_usuario   := null;
            v_hora          := null;
            p_monto         := 0;
        END;    
      WHEN OTHERS THEN
        p_cod_moneda    := null;
        p_nro_cuenta    := null;
        p_nro_documento := null;
        p_nro_caja      := null;
        v_fecha         := null;
        v_cod_usuario   := null;
        v_hora          := null;
        p_monto         := 0;         
    END;
    BEGIN 
      SELECT DISTINCT 'P'      
        INTO p_estado
        FROM ge_movimientos
       WHERE fecha = v_fecha
         AND cod_usuario = v_cod_usuario
         AND hora = v_hora
         AND estado <> 'N';
    EXCEPTION
      WHEN OTHERS THEN
        p_estado := 'N';
    END;
    p_cod_usuario := v_cod_usuario;
  ELSE
    IF p_nro_caja IS NOT NULL THEN
       BEGIN
         SELECT p.nro_referencia, SUM(p.monto)
           INTO p_nro_referencia, p_monto
           FROM cj_mov_prodep p
          WHERE p.fecha         = p_fecha
            AND p.hora          = p_hora
            AND p.nro_caja      = p_nro_caja
            AND p.estado <> 'R'
          GROUP BY p.nro_referencia;
       EXCEPTION
         WHEN OTHERS THEN
           p_nro_referencia := null;
           p_monto := 0;
       END;
    ELSE   
       BEGIN
         SELECT p.nro_referencia, SUM(p.monto)
           INTO p_nro_referencia, p_monto
           FROM cj_mov_prodep p
          WHERE p.fecha         = p_fecha
            AND p.hora          = p_hora
            AND p.cod_usuario   = p_cod_usuario
            AND p.estado <> 'R'
          GROUP BY p.nro_referencia;
       EXCEPTION
         WHEN OTHERS THEN
           p_nro_referencia := null;
           p_monto := 0;
       END;
    END IF;  
  END IF;    
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20002, 'ERROR. en PRJ_OBT_CAJ_MOV_PRODEP '||sqlerrm);
END;
/

