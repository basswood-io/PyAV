from av.audio.format cimport get_audio_format
from av.audio.frame cimport alloc_audio_frame
from av.audio.layout cimport get_audio_layout
from av.utils cimport err_check


cdef class AudioFifo:

    """A simple audio FIFO (First In First Out) buffer.



    """
        
    def __repr__(self):
        return '<av.%s %s samples of %dhz %s %s at 0x%x>' % (
            self.__class__.__name__,
            self.samples,
            self.sample_rate,
            self.layout,
            self.format,
            id(self),
        )
        
    def __dealloc__(self):
        if self.ptr:
            lib.av_audio_fifo_free(self.ptr)

    cpdef write(self, AudioFrame frame):
        """Push some samples into the queue."""

        if not self.ptr:

            if frame is None:
                raise ValueError('Cannot flush AudioFifo before it has started.')

            # Hold onto a copy of the attributes of the first frame to populate
            # output frames with.
            self.template = alloc_audio_frame()
            self.template._copy_internal_attributes(frame)
            self.template._init_user_attributes()

            # Figure out our "time_base".
            if frame._time_base.num and frame.ptr.sample_rate:
                self.pts_per_sample  = frame._time_base.den / float(frame._time_base.num)
                self.pts_per_sample /= frame.ptr.sample_rate
            else:
                self.pts_per_sample = 0

            self.ptr = lib.av_audio_fifo_alloc(
                <lib.AVSampleFormat>frame.ptr.format,
                len(frame.layout.channels), # TODO: Can we safely use frame.ptr.nb_channels?
                frame.ptr.nb_samples * 2, # Just a default number of samples; it will adjust.
            )

            if not self.ptr:
                raise RuntimeError('Could not allocate AVAudioFifo.')
        
        # Make sure nothing changed.
        elif frame and frame.ptr.nb_samples and (
            frame.ptr.format         != self.template.ptr.format or
            frame.ptr.channel_layout != self.template.ptr.channel_layout or
            frame.ptr.sample_rate    != self.template.ptr.sample_rate or
            (frame._time_base.num and self.template._time_base.num and (
                frame._time_base.num     != self.template._time_base.num or
                frame._time_base.den     != self.template._time_base.den
            ))
        ):
            raise ValueError('Frame does not match AudioFifo parameters.')

        # Assert that the PTS are what we expect.
        cdef uint64_t expected_pts
        if frame.ptr.pts != lib.AV_NOPTS_VALUE:
            expected_pts = <uint64_t>(self.pts_per_sample * self.samples_written)
            if frame.ptr.pts != expected_pts:
                raise ValueError('Input frame has pts %d; we expected %d.' % (frame.ptr.pts, expected_pts))
            
        err_check(lib.av_audio_fifo_write(
            self.ptr, 
            <void **>frame.ptr.extended_data,
            frame.ptr.nb_samples,
        ))

        self.samples_written += frame.ptr.nb_samples


    cpdef read(self, unsigned int samples=0, bint partial=False):
        """Read samples from the queue.

        :param int samples: The number of samples to pull; 0 gets all.
        :param bool partial: Allow returning less than requested.
        :returns: New :class:`AudioFrame` or ``None`` (if empty).

        If the incoming frames had valid timestamps, the returned frames
        will have accurate timestamps (assuming a time_base or 1/sample_rate).

        """

        if not self.ptr:
            return

        cdef int buffered_samples = lib.av_audio_fifo_size(self.ptr)
        if buffered_samples < 1:
            return

        samples = samples or buffered_samples

        if buffered_samples < samples:
            if partial:
                samples = buffered_samples
            else:
                return

        cdef AudioFrame frame = alloc_audio_frame()
        frame._copy_internal_attributes(self.template)
        frame._init(
            <lib.AVSampleFormat>self.template.ptr.format,
            self.template.ptr.channel_layout,
            samples,
            1, # Align?
        )

        err_check(lib.av_audio_fifo_read(
            self.ptr,
            <void **>frame.ptr.extended_data,
            samples,
        ))
        
        if self.pts_per_sample:
            frame.ptr.pts = <uint64_t>(self.pts_per_sample * self.samples_read)
        
        self.samples_read += samples

        return frame
    
    property format:
        def __get__(self):
            return self.template.format
    property layout:
        def __get__(self):
            return self.template.layout
    property sample_rate:
        def __get__(self):
            return self.template.sample_rate

    property samples:
        """Number of audio samples (per channel) """
        def __get__(self):
            return lib.av_audio_fifo_size(self.ptr) if self.ptr else 0

